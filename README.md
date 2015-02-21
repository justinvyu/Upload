# Upload
Photo Uploading Module

SMALL FIXES:

- Flash button disappears forever
- Get rid of "step 2" screen, go directly from 1-3
- Fix the event foursquare thing to get events only
- Images for cancel button and capture button look weird, might need to get better images
- Positioning of buttons is still a little weird

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

~~done~~

List of Things To Do:

For UI:

1. Choose tag within the same screen or other smarter/smooth ways to allow user to choose the tag (see whether you can put this into work: https://github.com/bestwnh/IGLDropDownMenu );

~~2. the first screen also need a X button to for user to cancel taking pictures;~~

~~3. Adding caption text box could be prettier - think some ways to make it look cleaner and more consistant with the rest of the screen.~~ MAYBE DONE

For Data:

1. Collect all the Foursquare, YELP, Google Places categories data;

2. Create a separate events category section from the above data, also Google some result about what possibly type of events it could be when you can take a picture to capture it.

Features:
- Taking a square image
- Add a caption
- Add a tag
- Get user's location
- Upload (with a resolution of 600x600 px)
