//
//  HexenTouchAppDelegate.h
//  HexenTouch
//
//  Created by Aurelio Reis on 6/10/08.
//  Copyright Dark Star Games 2008. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EAGLView;

@interface HexenTouchAppDelegate : NSObject <UIApplicationDelegate> {
	IBOutlet UIWindow *window;
	IBOutlet EAGLView *glView;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) EAGLView *glView;

- (void)CreateHexenThread;

@end

