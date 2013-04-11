#import "AudioHelper.h"

@implementation AudioHelper  {
}

#pragma mark - Class methods

+ (void) vibrate {
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}
@end
