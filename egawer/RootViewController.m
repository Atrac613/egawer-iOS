//
//  RootViewController.m
//  egawer
//
//  Created by Osamu Noguchi on 9/25/11.
//  Copyright 2011 atrac613.io. All rights reserved.
//

#import "RootViewController.h"
#import "UIImage+AutoLevels.h"

@implementation RootViewController
@synthesize captureSession;
@synthesize videoOutput;
@synthesize smileRectangles;
@synthesize smileView;
@synthesize smileLabel;
@synthesize soundLists;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.navigationItem setTitle:@"Egawer"];
    
    [self initOpenCV];
    
    captureSession = [[[AVCaptureSession alloc] init] autorelease];
    
    if ([captureSession canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        captureSession.sessionPreset = AVCaptureSessionPresetMedium;
    }
    
    AVCaptureDevice *captureDevice = [self frontFacingCameraIfAvailable];
    
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:nil];
    [captureSession addInput:input];
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    videoPreviewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:videoPreviewLayer];
    
    videoOutput = [[[AVCaptureVideoDataOutput alloc] init] autorelease];
    videoOutput.videoSettings = [NSDictionary dictionaryWithObject:
								 [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    dispatch_queue_t queue = dispatch_queue_create("videoBufferQueue", NULL);
    dispatch_queue_t high_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_set_target_queue(queue, high_queue);
    [videoOutput setSampleBufferDelegate:self queue:queue];
    
    videoOutput.minFrameDuration = CMTimeMake(1, 24);
    videoOutput.alwaysDiscardsLateVideoFrames = YES;
    [captureSession addOutput:videoOutput];
    
    [captureSession commitConfiguration];
    [captureSession startRunning];
    
    UIImage *smile = [UIImage imageNamed:@"smile.png"];
    smileView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 140, 140)];
    [smileView setCenter:CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2 - 80)];
    [smileView setImage:smile];
    [smileView setAlpha:0.3f];
    [self.view addSubview:smileView];
    
    smileLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 240, 30)];
    [smileLabel setText:NSLocalizedString(@"SMILE_PLEASE", @"Smile Please!")];
    [smileLabel setBackgroundColor:[UIColor clearColor]];
    [smileLabel setTextAlignment:UITextAlignmentCenter];
    [smileLabel setCenter:CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2)];
    [smileLabel setFont:[UIFont systemFontOfSize:25]];
    [smileLabel setTextColor:[UIColor whiteColor]];
    [self.view addSubview:smileLabel];
}

- (void)initOpenCV {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"smile1" ofType:@"xml"];
	cascade = (CvHaarClassifierCascade*)cvLoad([path cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL, NULL);
	storage = cvCreateMemStorage(0);	
}

- (void)releaseOpenCV {
	cvReleaseMemStorage(&storage);
	cvReleaseHaarClassifierCascade(&cascade);
}

- (AVCaptureDevice *)frontFacingCameraIfAvailable {
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *captureDevice = nil;
    
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == AVCaptureDevicePositionFront) {
            captureDevice = device;
            break;
        }
    }
    
    if (!captureDevice) {
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    return captureDevice;
}

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer {
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer); 
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    if (!colorSpace) 
    {
        NSLog(@"CGColorSpaceCreateDeviceRGB failure");
        return nil;
    }
    
    // Get the base address of the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    // Get the data size for contiguous planes of the pixel buffer.
    size_t bufferSize = CVPixelBufferGetDataSize(imageBuffer); 
    
    // Create a Quartz direct-access data provider that uses data we supply
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, baseAddress, bufferSize, 
															  NULL);
    // Create a bitmap image from data supplied by our data provider
    CGImageRef cgImage = 
	CGImageCreate(width,
				  height,
				  8,
				  32,
				  bytesPerRow,
				  colorSpace,
				  kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little,
				  provider,
				  NULL,
				  true,
				  kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
	UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    return image;	
}

- (IplImage *)CreateIplImageFromUIImage:(UIImage *)image {
	CGImageRef imageRef = image.CGImage;
    
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
    
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
    
	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
	cvCvtColor(iplimage, ret, CV_RGBA2BGR);
	cvReleaseImage(&iplimage);
    
	return ret;
}

- (IplImage *)rotateImage:(IplImage *)image angle:(double)angle {
    IplImage *rotatedImage = cvCreateImage(cvSize(360, 480), IPL_DEPTH_8U, image->nChannels);
    
    CvPoint2D32f center;
    center.x = 180;
    center.y = 240;
    CvMat *mapMatrix = cvCreateMat(2, 3, CV_32FC1);
    
    cv2DRotationMatrix(center, angle, 1.0, mapMatrix);
    cvWarpAffine(image, rotatedImage, mapMatrix, CV_INTER_LINEAR + CV_WARP_FILL_OUTLIERS, cvScalarAll(0));
    
    cvReleaseImage(&image);
    cvReleaseMat(&mapMatrix);
    
    return rotatedImage;
}

- (void)opencvSmileDetect:(UIImage *)originalImage {	
	cvSetErrMode(CV_ErrModeParent);
    
	IplImage *image = [self rotateImage:[self CreateIplImageFromUIImage:originalImage] angle:-90.f];
    
	// Scaling down
	IplImage *small_image = cvCreateImage(cvSize(image->width/2, image->height/2), IPL_DEPTH_8U, 3);
	cvPyrDown(image, small_image, CV_GAUSSIAN_5x5);
    cvReleaseImage(&image);
    
	int scale = 2;
    
	// Detect smiles and draw rectangle on them
    CvSeq *smiles = cvHaarDetectObjects(small_image, cascade, storage, 1.2f, 2, CV_HAAR_DO_CANNY_PRUNING, cvSize(0, 0), cvSize(20, 20));
    cvReleaseImage(&small_image);	
    
    NSLog(@"Detect: %d", smiles->total);
    
	// Draw results on the iamge
	NSMutableArray *rects = [[NSMutableArray alloc] initWithCapacity:smiles->total];
	for(int i=0; i < smiles->total; i++) {
		CvRect cvrect = *(CvRect*)cvGetSeqElem(smiles, 0);
		CGRect rect = CGRectMake((CGFloat)(cvrect.x * scale), 													 
								 (CGFloat)(cvrect.y * scale), 
								 (CGFloat)(cvrect.width * scale), 
								 (CGFloat)(cvrect.height * scale));								
		[rects addObject:[NSValue valueWithCGRect:rect]];
	}
    
	[smileRectangles release];
	smileRectangles = rects;
}


-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef) sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
	UIImage *image = [[self imageFromSampleBuffer:sampleBuffer] imageWithAutoLevels];
    
	[self opencvSmileDetect:image];		
	
    dispatch_async(dispatch_get_main_queue(), ^ {			
		if ([smileRectangles count] > 0) {
			CGRect rect = [[smileRectangles objectAtIndex:0] CGRectValue];
			NSLog(@"det rect: %1.2f %1.2f %1.2f %1.2f", rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
            
            [smileView setAlpha:1];
            [smileLabel setText:NSLocalizedString(@"NICE", @"Nice!")];
            
            [NSThread detachNewThreadSelector:@selector(playSound) toTarget:self withObject:nil];
		} else {
            [smileView setAlpha:0.3f];
            [smileLabel setText:NSLocalizedString(@"SMILE_PLEASE", @"Smile Please!")];
        }
	});
}

- (void)playSound {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSString *soundFile = [NSString stringWithFormat:@"laugh_%d", (1 + arc4random() % 11)];
    
    NSString *soundPath = [[NSBundle mainBundle] pathForResource:soundFile ofType:@"caf"];
    NSURL *file = [[[NSURL alloc] initFileURLWithPath:soundPath] autorelease];
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:file error:nil];
    
    [player setDelegate:self];
    [player prepareToPlay];
    
    [player play];
    
    [pool release];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations.
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}

- (void)dealloc
{
    [super dealloc];
    
    [self releaseOpenCV];
}

@end
