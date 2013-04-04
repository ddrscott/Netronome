//
// MBProgressHUD.m
// Version 0.5
// Created by Matej Bukovinski on 2.4.09.
//

#import "AudioHelper.h"

@implementation AudioHelper  {
//    // class variables here
}

#pragma mark - Class methods

+ (void) vibrate {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}
@end
