# Upload
Photo Uploading Module

SMALL FIXES:

~~- Flash button disappears forever~~
~~- Get rid of "step 2" screen, go directly from 1-3~~
- Fix the event foursquare thing to get events only
- Images for cancel button and capture button look weird, might need to get better images
~~- Positioning of buttons is still a little weird~~

To implement:

```Objective-C
- (void)presentCameraVC {
	IUUploadViewController *uvc = [[IUUploadViewController alloc] init];
	[self presentViewController:uvc animated:YES completion:nil];
}
```

Files needed:
```Objective-C
#import "IUUploadViewController"
#import "IUPostPhotoViewController"

#import "AVCamPreviewView.h"
#import "UploadConstants.h"
#import "UIImage+ResizeAdditions.h"
#import "IUPostPhotoTableViewController.h"
#import "CameraFocusSquareView.h"
#import "Event.h"

#import <Parse/Parse.h>
#import <AVFoundation/AVFoundation.h>

#import <SZTextView/SZTextView.h>
#import <ActionSheetPicker-3.0/ActionSheetPicker.h>
#import <RestKit/RestKit.h>
```
