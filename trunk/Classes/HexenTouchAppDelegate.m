//
//  HexenTouchAppDelegate.m
//  HexenTouch
//
//  Created by Aurelio Reis on 6/10/08.
//  Copyright Dark Star Games 2008. All rights reserved.
//

#import "HexenTouchAppDelegate.h"
#import "EAGLView.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>

#include <OpenAl/al.h>
#include <OpenAl/alc.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AudioToolbox/AudioServices.h>

// For posix threads.
#include <pthread.h>

@implementation HexenTouchAppDelegate

@synthesize window;
@synthesize glView;

extern void ibm_main(int argc, char **argv);

CFTimeInterval g_fAbsTime = 0.0f;
CFTimeInterval g_fStartTime = 0.0f;


// Vibrate on damage.
void iPhoneVibrate()
{
	AudioServicesPlaySystemSound( kSystemSoundID_Vibrate );
}

typedef ALvoid	AL_APIENTRY	(*alBufferDataStaticProcPtr) (const ALint bid, ALenum format, ALvoid* data, ALsizei size, ALsizei freq);
ALvoid  alBufferDataStaticProc(const ALint bid, ALenum format, ALvoid* data, ALsizei size, ALsizei freq)
{
	static	alBufferDataStaticProcPtr	proc = NULL;
    
    if (proc == NULL) {
        proc = (alBufferDataStaticProcPtr) alcGetProcAddress(NULL, (const ALCchar*) "alBufferDataStatic");
    }
    
    if (proc)
        proc(bid, format, data, size, freq);
	
    return;
}

typedef struct soundChannel_s
{
	ALuint Buffer;
	ALuint Source;
	int Priority;
} soundChannel_t;

#define NUM_SOUND_CHANNELS	16
soundChannel_t g_SoundChannels[ NUM_SOUND_CHANNELS ];

void InitSoundChannels()
{
#if TARGET_IPHONE_SIMULATOR 
	return;
#endif
	
	ALfloat ListenerPos[] = { 0.0, 0.0, 0.0 };
	ALfloat ListenerVel[] = { 0.0, 0.0, 0.0 };
	ALfloat ListenerOri[] = { 0.0, 0.0, -1.0,  0.0, 1.0, 0.0 };
	
	int iErr = alGetError();
	
	for ( int i = 0; i < NUM_SOUND_CHANNELS; ++i )
	{
		soundChannel_t *pChan = &g_SoundChannels[ i ];
		
		alGenBuffers( 1, &pChan->Buffer );
		iErr = alGetError();
		assert( iErr == AL_NO_ERROR );
		alGenSources( 1, &pChan->Source );
		iErr = alGetError();
		assert( iErr == AL_NO_ERROR );
		
		pChan->Priority = 0;
	}
	
	alListenerfv( AL_POSITION,    ListenerPos );
	alListenerfv( AL_VELOCITY,    ListenerVel );
	alListenerfv( AL_ORIENTATION, ListenerOri );
	iErr = alGetError();
	assert( iErr == AL_NO_ERROR );	
}

void DestroySoundChannels()
{
#if TARGET_IPHONE_SIMULATOR 
	return;
#endif
	
	for ( int i = 0; i < NUM_SOUND_CHANNELS; ++i )
	{
		alSourceStop( g_SoundChannels[ i ].Source );
		alDeleteSources( 1, &g_SoundChannels[ i ].Source );
		alDeleteBuffers( 1, &g_SoundChannels[ i ].Buffer );
	}	
}

soundChannel_t *FindFreeSoundChannel(  int priority )
{
	// A sound channel is free if it is not used (not playing a sound), or, if the no channels are free, if the
	// priority of one of those channels is less than that of the new sound to play.
	
	ALenum state;
	soundChannel_t *pLowestPriorChan = g_SoundChannels[ 0 ].Priority < priority ? &g_SoundChannels[ 0 ] : NULL;
	
	for ( int i = 0; i < NUM_SOUND_CHANNELS; ++i )
	{
		soundChannel_t *pChan = &g_SoundChannels[ i ];
		
		alGetSourcei( pChan->Source, AL_SOURCE_STATE, &state );

		if ( state == AL_STOPPED || state == AL_INITIAL )
		{
			// Easy. Found an unused channel.
			return pChan;
		}
	
		if ( pChan->Priority < priority )
		{
			if ( pLowestPriorChan )
			{
				if ( pChan->Priority < pLowestPriorChan->Priority )
				{
					pLowestPriorChan = pChan;
				}
			}
			else
			{
				pLowestPriorChan = pChan;
			}
		}
	}
	
	return pLowestPriorChan;
}

#define SOUND_SAMPLE_RATE		11025
#define SOUND_FORMAT			AL_FORMAT_MONO8

void iPhonePlaySound( void *data, int len, int priority, int vol )
{
#if TARGET_IPHONE_SIMULATOR 
	return;
#endif
	
	soundChannel_t *pChan = FindFreeSoundChannel( priority );
	
	// If we couldn't find an open channel or one with a lower priority than this sound, skip it.
	if ( !pChan )
	{
		return;
	}
	
	pChan->Priority = priority;
	
	// Header offset.
	#define SOUND_DATA_OFFSET 8
	data += SOUND_DATA_OFFSET;
	
	alGetError();
	
	alSourceStop( pChan->Source );
	assert( alGetError() == AL_NO_ERROR );
	
	// The buffer can't just be refreshed (like glTexImage2D) so we have to destroy and recreate it manually.
	alDeleteSources( 1, &pChan->Source );
	assert( alGetError() == AL_NO_ERROR );
	alDeleteBuffers( 1, &pChan->Buffer );
	assert( alGetError() == AL_NO_ERROR );
	alGenBuffers( 1, &pChan->Buffer );
	assert( alGetError() == AL_NO_ERROR );
	alGenSources( 1, &pChan->Source );
	assert( alGetError() == AL_NO_ERROR );
	
	alBufferDataStaticProc( pChan->Buffer, SOUND_FORMAT, data, len, SOUND_SAMPLE_RATE );
	assert( alGetError() == AL_NO_ERROR );
	
	float fVol = vol / 255.0f;
	
	alSourcei( pChan->Source, AL_BUFFER, pChan->Buffer );
	alSourcef( pChan->Source, AL_GAIN, fVol  );
	alSourcef( pChan->Source, AL_PITCH,    1.0f  );
	ALfloat SourcePos[] = { 0.0, 0.0, 0.0 };
	ALfloat SourceVel[] = { 0.0, 0.0, 0.0 };	
	alSourcefv( pChan->Source, AL_POSITION, SourcePos );
	alSourcefv( pChan->Source, AL_VELOCITY, SourceVel );
	alSourcei( pChan->Source, AL_LOOPING,  false );
	assert( alGetError() == AL_NO_ERROR );
	
	alSourcePlay( pChan->Source );
	assert( alGetError() == AL_NO_ERROR );
}

ALCcontext*								mContext;
ALCdevice*								mDevice;

typedef ALvoid	AL_APIENTRY	(*alcMacOSXMixerOutputRateProcPtr) (const ALdouble value);
ALvoid  alcMacOSXMixerOutputRateProc(const ALdouble value)
{
	static	alcMacOSXMixerOutputRateProcPtr	proc = NULL;
    
    if (proc == NULL) {
        proc = (alcMacOSXMixerOutputRateProcPtr) alcGetProcAddress(NULL, (const ALCchar*) "alcMacOSXMixerOutputRate");
    }
    
    if (proc)
        proc(value);
	
    return;
}

void InitOpenAL()
{
	int iErr = alGetError();
	
	//OSStatus result = noErr;
	mDevice = alcOpenDevice( NULL );
	iErr = alGetError();
	assert( iErr == AL_NO_ERROR );
	
	int iOutputRate = 11025;
	
	// If a mixer output rate was specified, set it here
	// must be done before the alcCreateContext() call.
	if ( iOutputRate )
		alcMacOSXMixerOutputRateProc( iOutputRate );
	
	// Create an OpenAL Context
	mContext = alcCreateContext(mDevice, NULL);
	iErr = alGetError();
	assert( iErr == AL_NO_ERROR );
	
	alcMakeContextCurrent(mContext);
	iErr = alGetError();
	assert( iErr == AL_NO_ERROR );
}


int iPhone_GetH2Tics()
{
	g_fAbsTime = CFAbsoluteTimeGetCurrent() - g_fStartTime;

	return (int)( g_fAbsTime * 35.0f );
}

char g_strBuffer[ 2048 ];

void *PosixThreadMainRoutine( void *data )
{
	ibm_main( 0, NULL );
	
	return NULL;
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{
	InitOpenAL();
	InitSoundChannels();
	
	g_fStartTime = CFAbsoluteTimeGetCurrent();;
	
	CFBundleRef mainBundle = CFBundleGetMainBundle();
	
	CFURLRef    wadURL;
	
	// Look for a resource in the main bundle by name and type.
	wadURL = CFBundleCopyResourceURL( mainBundle, CFSTR( "hexen" ), CFSTR( "wad" ), NULL );

	CFURLGetFileSystemRepresentation( wadURL, true,  (UInt8 *)g_strBuffer, 2048 );
	
	glView.multipleTouchEnabled = YES;
	[glView layoutSubviews];
	
	[self CreateHexenThread];
}


- (void)applicationWillResignActive:(UIApplication *)application {
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)dealloc {
	[window release];
	[glView release];
	[super dealloc];
	
	DestroySoundChannels();
	if (mContext) alcDestroyContext(mContext);
	if (mDevice) alcCloseDevice(mDevice);
}

- (void)CreateHexenThread
{
	// Create the thread using POSIX routines.
	pthread_attr_t		attr;
	pthread_t			posixThreadID;
	int				returnVal;

	returnVal = pthread_attr_init( &attr );
	assert(!returnVal);
	returnVal = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
	assert(!returnVal);

	int     threadError = pthread_create( &posixThreadID, &attr, &PosixThreadMainRoutine, NULL );

	returnVal = pthread_attr_destroy(&attr);
	assert(!returnVal);
	if (threadError != 0)
	{
		// Report an error.
	}
}

@end
