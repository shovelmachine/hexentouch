//
//  EAGLView.m
//  HexenTouch
//
//  Created by Aurelio Reis on 6/10/08.
//  Copyright Dark Star Games 2008. All rights reserved.
//



#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>

#import "EAGLView.h"

#import "HexenTouchAppDelegate.h"

void iPhone_ScreenUpdate( int subchanged );

const float g_fDisplayWidth = 1;
const float g_fDisplayHeight = 1;

bool g_bSubchanged = true;

//ortho view matrix
static void GL_ToOrtho(void)
{
	glMatrixMode(GL_PROJECTION);
	glPushMatrix();
	glLoadIdentity();
	glOrthof(0, g_fDisplayWidth, g_fDisplayHeight, 0, -1, 1);
	glMatrixMode(GL_MODELVIEW);
	glPushMatrix();
	glLoadIdentity();
}

//perspective view matrix
static void GL_BackToPerspective(void)
{
	glMatrixMode(GL_PROJECTION);
	glPopMatrix();
	glMatrixMode(GL_MODELVIEW);
	glPopMatrix();
}

#define USE_DEPTH_BUFFER 0

// A class extension to declare private methods
@interface EAGLView ()

@property (nonatomic, retain) EAGLContext *context;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;

@end


@implementation EAGLView

@synthesize context;


// You must implement this
+ (Class)layerClass {
	return [CAEAGLLayer class];
}


//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder {

	if ((self = [super initWithCoder:coder])) {
		// Get the layer
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
		   [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		
		context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
		
		if (!context || ![EAGLContext setCurrentContext:context]) {
			[self release];
			return nil;
		}
	}
	return self;
}

unsigned int g_iTex  = 0;
unsigned int g_iTex2  = 0;

#include "h2def.h"

#define	H2SCREENWIDTH		SCREENWIDTH
#define	H2SCREENHEIGHT	SCREENHEIGHT

#define SCREENTEXTUREWIDTH			512
#define SCREENTEXTUREHEIGHT		512

extern byte softPCScreenPal[ 256 * 3 ];
extern byte softPCScreenBuffer [ H2SCREENWIDTH * H2SCREENHEIGHT ];
extern byte softSubPCScreenBuffer[ DRAWSCREENWIDTH * DRAWSCREENHEIGHT ];

typedef struct rgbPixel_s
{
	byte rgb[ 3 ];
} rgbPixel_t;
static rgbPixel_t g_debugPixBuffer[ SCREENTEXTUREWIDTH * SCREENTEXTUREHEIGHT ];

void ClearBuffer(  rgbPixel_t *dest )
{
	memset( dest, 0, sizeof( rgbPixel_t ) * SCREENTEXTUREWIDTH * SCREENTEXTUREHEIGHT );
}

void UpdateBuffer( rgbPixel_t *dest, byte *src )
{
	// Update the screen texture to the screen rect.
	int i = 0;
	for ( int y = 0; y < H2SCREENHEIGHT; y++ )
	{
		const int iYOffset = y * SCREENTEXTUREWIDTH;
		for ( int x = 0; x < H2SCREENWIDTH; x++ )
		{
			int iIdx = iYOffset + x;
			int curSrc = src[ i++ ] * 3;
			dest[ iIdx ].rgb[ 0 ] = softPCScreenPal[ curSrc  ];
			dest[ iIdx ].rgb[ 1 ] = softPCScreenPal[ curSrc + 1 ];
			dest[ iIdx ].rgb[ 2 ] = softPCScreenPal[ curSrc + 2 ];
		}
	}	
}

- (void)drawView
{	
	[EAGLContext setCurrentContext:context];
	
	int iErr = glGetError();
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glViewport(0, 0, backingWidth, backingHeight);
	
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
	glClear(GL_COLOR_BUFFER_BIT);
	
	iErr = glGetError();
	assert( iErr == GL_NO_ERROR );
	
	UpdateBuffer( g_debugPixBuffer, softPCScreenBuffer );
	
	// Upload updated texture data.
	glEnable( GL_TEXTURE_2D ); 
	glBindTexture( GL_TEXTURE_2D, g_iTex );
	glTexSubImage2D( GL_TEXTURE_2D, 0, 0, 0, SCREENTEXTUREWIDTH, SCREENTEXTUREHEIGHT, GL_RGB, GL_UNSIGNED_BYTE, g_debugPixBuffer ); 
	
	iErr = glGetError();
	assert( iErr == GL_NO_ERROR );
	
	// Stagger updates.
extern CFTimeInterval g_fAbsTime;
	static CFTimeInterval g_fTimer = 0.0f;
	if ( g_bSubchanged && g_fTimer < g_fAbsTime )
	{
		// Next update.
		g_fTimer = g_fAbsTime + 0.5f;
		
		UpdateBuffer( g_debugPixBuffer, softSubPCScreenBuffer );

		glBindTexture( GL_TEXTURE_2D, g_iTex2 );
		glTexSubImage2D( GL_TEXTURE_2D, 0, 0, 0, SCREENTEXTUREWIDTH, SCREENTEXTUREHEIGHT, GL_RGB, GL_UNSIGNED_BYTE, g_debugPixBuffer ); 
		glDisable( GL_TEXTURE_2D );
		
		iErr = glGetError();
		assert( iErr == GL_NO_ERROR );
	}
	
	// Adjust for not being able to use non-power-of-two textures.
	static const float fWidthRatio = H2SCREENWIDTH / (float)SCREENTEXTUREWIDTH;
	static const float fHeightRatio = H2SCREENHEIGHT / (float)SCREENTEXTUREHEIGHT;
	
	const GLfloat squareTc[] =
	{
		0.0f, fHeightRatio,
		0.0f, 0.0f,
		fWidthRatio,  fHeightRatio,
		fWidthRatio,  0.0f,
	};
	
	GL_ToOrtho();
		
	//float fVertHeightRatio = H2SCREENHEIGHT / 480.0f;
	
	 const GLfloat squareVertices[] =
	{
		 0.0f, g_fDisplayHeight * 0.5f,
		 0.0f, 0.0f,
		 g_fDisplayWidth,  g_fDisplayHeight * 0.5f,
		 g_fDisplayWidth,  0.0f,
	 };

	glEnableClientState( GL_VERTEX_ARRAY );
	glEnableClientState( GL_TEXTURE_COORD_ARRAY );
	
	glVertexPointer( 2, GL_FLOAT, 0, squareVertices );
	glTexCoordPointer( 2, GL_FLOAT, 0, squareTc );
	
	glEnable( GL_TEXTURE_2D); 

	glBindTexture( GL_TEXTURE_2D, g_iTex );
	glTexEnvi( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );

	glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );
	
	const GLfloat squareVertices2[] =
	{
		0.0f, g_fDisplayHeight,
		0.0f, g_fDisplayHeight * 0.5f,
		g_fDisplayWidth,  g_fDisplayHeight,
		g_fDisplayWidth,  g_fDisplayHeight * 0.5f,
	};
	
	glVertexPointer( 2, GL_FLOAT, 0, squareVertices2 );
	
	glBindTexture( GL_TEXTURE_2D, g_iTex2 );
	glTexEnvi( GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
	
	glDrawArrays( GL_TRIANGLE_STRIP, 0, 4 );
	
	glDisable(GL_TEXTURE_2D); 

	GL_BackToPerspective();
	
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];
}


- (void)layoutSubviews {
	[EAGLContext setCurrentContext:context];
	[self destroyFramebuffer];
	[self createFramebuffer];
	
	ClearBuffer( g_debugPixBuffer );

	if ( g_iTex == 0 )
	{
		glGenTextures( 1, &g_iTex );
		
		glBindTexture( GL_TEXTURE_2D, g_iTex );
		glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, SCREENTEXTUREWIDTH, SCREENTEXTUREHEIGHT, 0, GL_RGB, GL_UNSIGNED_BYTE, 0 );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
		
		// Upload updated texture data.
		glEnable( GL_TEXTURE_2D ); 
		glBindTexture( GL_TEXTURE_2D, g_iTex );
		glTexSubImage2D( GL_TEXTURE_2D, 0, 0, 0, SCREENTEXTUREWIDTH, SCREENTEXTUREHEIGHT, GL_RGB, GL_UNSIGNED_BYTE, g_debugPixBuffer ); 
		assert( glGetError() == GL_NO_ERROR );	
	}
	
	if ( g_iTex2 == 0 )
	{
		glGenTextures( 1, &g_iTex2 );
		
		glBindTexture( GL_TEXTURE_2D, g_iTex2 );
		glTexImage2D( GL_TEXTURE_2D, 0, GL_RGB, SCREENTEXTUREWIDTH, SCREENTEXTUREHEIGHT, 0, GL_RGB, GL_UNSIGNED_BYTE, 0 );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
		glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
		
		// Upload updated texture data.
		glEnable( GL_TEXTURE_2D ); 
		glBindTexture( GL_TEXTURE_2D, g_iTex2 );
		glTexSubImage2D( GL_TEXTURE_2D, 0, 0, 0, SCREENTEXTUREWIDTH, SCREENTEXTUREHEIGHT, GL_RGB, GL_UNSIGNED_BYTE, g_debugPixBuffer ); 
		assert( glGetError() == GL_NO_ERROR );		
	}	
	
	//[self drawView];
}


- (BOOL)createFramebuffer {
	
	glGenFramebuffersOES(1, &viewFramebuffer);
	glGenRenderbuffersOES(1, &viewRenderbuffer);
	
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
	
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
	glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
	
	if (USE_DEPTH_BUFFER) {
		glGenRenderbuffersOES(1, &depthRenderbuffer);
		glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
		glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
		glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
	}

	if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
		NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
		return NO;
	}
	
	return YES;
}


- (void)destroyFramebuffer {
	
	glDeleteFramebuffersOES(1, &viewFramebuffer);
	viewFramebuffer = 0;
	glDeleteRenderbuffersOES(1, &viewRenderbuffer);
	viewRenderbuffer = 0;
	
	if(depthRenderbuffer)
	{
		glDeleteRenderbuffersOES(1, &depthRenderbuffer);
		depthRenderbuffer = 0;
	}
}

- (void)dealloc {
	if ([EAGLContext currentContext] == context) {
		[EAGLContext setCurrentContext:nil];
	}
	
	[context release];	
	[super dealloc];
}

// H2 key codes.
#define	KEY_RIGHTARROW		0xae
#define	KEY_LEFTARROW		0xac
#define	KEY_UPARROW			0xad
#define	KEY_DOWNARROW		0xaf
#define	KEY_ESCAPE			27
#define	KEY_ENTER			13
#define	KEY_F1				(0x80+0x3b)
#define	KEY_F2				(0x80+0x3c)
#define	KEY_F3				(0x80+0x3d)
#define	KEY_F4				(0x80+0x3e)
#define	KEY_F5				(0x80+0x3f)
#define	KEY_F6				(0x80+0x40)
#define	KEY_F7				(0x80+0x41)
#define	KEY_F8				(0x80+0x42)
#define	KEY_F9				(0x80+0x43)
#define	KEY_F10				(0x80+0x44)
#define	KEY_F11				(0x80+0x57)
#define	KEY_F12				(0x80+0x58)
#define KEY_TAB				9
#define	KEY_RSHIFT			(0x80+0x36)
#define	KEY_RCTRL			(0x80+0x1d)
#define	KEY_RALT			(0x80+0x38)

extern void ibm_handlewinkey(int key, int up);
void TouchScreenSample();
int TouchScreenLook();
int TouchScreenYaw();

static int lastTouchX = -2;
static int lastTouchY = -2;
static int curTouchXDif = 0;
static int curTouchYDif = 0;
static int lastTouchXDif = 0;
static int lastTouchYDif = 0;

CGPoint startTouchPosition;
CGPoint lastTouchPosition;

extern void iPhoneCheatGod();
extern void iPhoneCheatWeapons();

int g_iTouchesDown = 0;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{ 
	UITouch *touch = [touches anyObject];
	
	NSEnumerator *enumerator = [touches objectEnumerator];
	UITouch *curTouch;
	
	int iNumTouches = [[event touchesForView:self]count];
	int iNumTaps = [touch tapCount];
	
	while ( ( curTouch = [enumerator nextObject] ) )
	{
		if ( iNumTaps <  [curTouch tapCount] )
		{
			iNumTaps =  [curTouch tapCount];
		}		
	}
	
	g_iTouchesDown += iNumTouches;
	
	startTouchPosition = [touch locationInView:self];
	
	int iYDif = ( lastTouchPosition.y - startTouchPosition.y );
	if ( iNumTouches == 2 && iYDif > 2 )
	{
		ibm_handlewinkey( KEY_UPARROW, false );	
	}
	
	lastTouchPosition = startTouchPosition;
	
	if ( iNumTaps == 3 )
	{
		// Use key.
		ibm_handlewinkey( (unsigned short)' ', false );
	}
	// Doubletap = Attack and Enter.
	else if ( iNumTaps == 2 )
	{ 
		ibm_handlewinkey( KEY_RCTRL, false );
		ibm_handlewinkey( KEY_ENTER, false );
		
		// Cancel.
		if ( iNumTouches == 2 )
		{
			ibm_handlewinkey( KEY_ESCAPE, false );
		}
	}
	
	ibm_handlewinkey( (unsigned short)'l', true );
} 

#define HORIZ_SWIPE_DRAG_MIN 12 
#define VERT_SWIPE_DRAG_MAX 4 

#define VERT_SWIPE_DRAG_MIN 12 
#define HORIZ_SWIPE_DRAG_MAX 4 

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	NSArray *pArray = [touches allObjects];
	UITouch *touch = [pArray objectAtIndex:0];
	//UITouch *touch = [touches anyObject]; 
	
	CGPoint currentTouchPosition = [touch locationInView:self]; 
	
	int iNumTouches = [[event touchesForView:self]count];

	if ( iNumTouches == 1 )
	{
		lastTouchX = currentTouchPosition.x;
		lastTouchY = currentTouchPosition.y;
		
		curTouchXDif =  lastTouchPosition.x - currentTouchPosition.x;
		curTouchYDif =  lastTouchPosition.y - currentTouchPosition.y;
		
		// Clamp huge values.
#define MAX_TOUCH_DIFF	12
		curTouchXDif = curTouchXDif > MAX_TOUCH_DIFF ? MAX_TOUCH_DIFF : curTouchXDif < -MAX_TOUCH_DIFF ? -MAX_TOUCH_DIFF : curTouchXDif;
		curTouchYDif = curTouchYDif > MAX_TOUCH_DIFF ? MAX_TOUCH_DIFF : curTouchYDif < -MAX_TOUCH_DIFF ? -MAX_TOUCH_DIFF : curTouchYDif;
		
		startTouchPosition = currentTouchPosition;
	}
			
	// Weapon cycle.
	if ( iNumTouches == 2 )
	{
		currentTouchPosition = [[touches anyObject] locationInView:self]; 
		int iYDif = ( startTouchPosition.y - currentTouchPosition.y );
		if ( iYDif < -120 )
		{
			ibm_handlewinkey( (unsigned short)'l', false );
		}
	}
	
	lastTouchPosition = currentTouchPosition;
	
	// Stop moving if they took the second finger off the screen.
	if ( iNumTouches != 2 )
	{
		ibm_handlewinkey( KEY_UPARROW, true );
	}
#if 0
	// If the swipe tracks correctly. 
	if ( fabsf(startTouchPosition.x - currentTouchPosition.x) >= HORIZ_SWIPE_DRAG_MIN && 
	     fabsf(startTouchPosition.y - currentTouchPosition.y) <= VERT_SWIPE_DRAG_MAX ) 
	{ 
		// It appears to be a swipe. 
		if (startTouchPosition.x < currentTouchPosition.x)
		{
			// Right swipe.
			//ibm_handlewinkey( KEY_RIGHTARROW, false );
		}
		else
		{
			// Left swipe.			
			//ibm_handlewinkey( KEY_LEFTARROW, false );
		}
	} 
	else 	if ( fabsf(startTouchPosition.y - currentTouchPosition.y) >= VERT_SWIPE_DRAG_MIN && 
		     fabsf(startTouchPosition.x - currentTouchPosition.x) <= HORIZ_SWIPE_DRAG_MAX ) 
	{
		if ( iNumTouches == 2 )
		{
			if (startTouchPosition.y < currentTouchPosition.y)
			{
				// Down swipe.
				ibm_handlewinkey( KEY_DOWNARROW, false );
			}
			else
			{
				// Up swipe.			
				ibm_handlewinkey( KEY_UPARROW, false );
			}
		}
	}
	else 
	{ 
		// Process a non-swipe event. 
	} 
#endif
}

// A tap starts game play
- (void)touchesEnded:(NSSet*)touches withEvent:(UIEvent*)event
{
	UITouch *touch = [touches anyObject]; 

	int iNumTouches = [[event touchesForView:self]count];
	int iNumTaps = [touch tapCount];
	
	CGPoint currentTouchPosition = [touch locationInView:self];
	lastTouchPosition = currentTouchPosition;

	g_iTouchesDown -= iNumTouches;

	if([touches count]==[[event touchesForView:self]count])
	{
		g_iTouchesDown = 0;

		//lastfingerhaslifted.... 
		
		ibm_handlewinkey( KEY_RCTRL, true );
		
		ibm_handlewinkey( KEY_LEFTARROW, true );
		ibm_handlewinkey( KEY_RIGHTARROW, true );
		ibm_handlewinkey( KEY_UPARROW, true );
		ibm_handlewinkey( KEY_DOWNARROW, true );		
		
		// Weapon cycle.
		ibm_handlewinkey( (unsigned short)'l', true );
		
		// Use key.
		ibm_handlewinkey( (unsigned short)' ', true );
		
		curTouchXDif = 0;
		curTouchYDif = 0;
		lastTouchXDif = 0;
		lastTouchYDif = 0;
		lastTouchX = -2;
		lastTouchY = -2;
	}
	
	if ( iNumTaps == 6 )
	{
		iPhoneCheatWeapons();
		iPhoneCheatGod();
	}
	
	// Stop moving if they took the second finger off the screen.
	if ( iNumTouches != 2 )
	{
		ibm_handlewinkey( KEY_UPARROW, true );
	}
	
	ibm_handlewinkey( (unsigned short)'l', true );
}

@end


void TouchScreenSample()
{
}

extern int mouseSensitivity;
extern int invertLook;

int TouchScreenLook()
{
	int touch = 0;
	int sens;
	if (lastTouchX < 0 || lastTouchY < 0)
	{
		return 0;
	}
	sens = mouseSensitivity>>1;
	if (sens < 1)
	{
		sens = 1;
	}
	
	if (lastTouchYDif > 12)
	{
		touch = 3;
	}
	else if (lastTouchYDif > 6)
	{
		touch = 2;
	}
	else if (lastTouchYDif > 0)
	{
		touch = 1;
	}
	if (lastTouchYDif < -12)
	{
		touch = -3;
	}
	else if (lastTouchYDif < -6)
	{
		touch = -2;
	}
	else if (lastTouchYDif < 0)
	{
		touch = -1;
	}
	if (invertLook)
	{
		touch = -touch;
	}
	lastTouchYDif = curTouchYDif;
	curTouchYDif = 0;	
	return (touch)*sens;	
}

int TouchScreenYaw()
{
	int sens, r;
	if (lastTouchX < 0 || lastTouchY < 0)
	{
		return 0;
	}
	sens = mouseSensitivity>>1;
	if (sens < 1)
	{
		sens = 1;
	}
	
	r = (lastTouchXDif*150)*sens;
	lastTouchXDif = curTouchXDif;
	curTouchXDif = 0;
	return r;
	
}

void iPhone_ScreenUpdate( int subchanged )
{
	g_bSubchanged = !!subchanged;
	
	EAGLView *glView = [(HexenTouchAppDelegate *)[[UIApplication sharedApplication] delegate] glView];
	[glView drawView];
}


