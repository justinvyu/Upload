# Upload
Photo Uploading Module

# Small Fixes

- Make the dismiss work

# Changes Needed

This change allows there to be only one camera focus square. This way, if the user clicks the screen multiple times, then there is only one camera focus square.

- Focus Method
- PWCamFocusSquare ()
- Add previousCamFocus property

# Implement

```Objective-C
- (void)presentCameraVC {
	IUUploadViewController *uvc = [[IUUploadViewController alloc] init];
	[self presentViewController:uvc animated:YES completion:nil];
}
```