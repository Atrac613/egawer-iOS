//
//  RootViewController.h
//  egawer
//
//  Created by Osamu Noguchi on 9/25/11.
//  Copyright 2011 atrac613.io. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <opencv2/imgproc/imgproc_c.h>
#import <opencv2/objdetect/objdetect.hpp>

@interface RootViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, AVAudioPlayerDelegate> {
    AVCaptureSession *captureSession;
    AVCaptureVideoDataOutput *videoOutput;
    
    CvHaarClassifierCascade *cascade;
    CvMemStorage *storage;
    
    NSArray *smileRectangles;
    
    UIImageView *smileView;
    UILabel *smileLabel;
    
    NSArray *soundLists;
}

@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoDataOutput *videoOutput;

@property (nonatomic, retain) NSArray *smileRectangles;

@property (nonatomic, retain) UIImageView *smileView;
@property (nonatomic, retain) UILabel *smileLabel;

@property (nonatomic, retain) NSArray *soundLists;

- (AVCaptureDevice *)frontFacingCameraIfAvailable;

- (void)initOpenCV;
- (void)releaseOpenCV;

- (void)opencvSmileDetect:(UIImage *)originalImage;

- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (IplImage *)rotateImage:(IplImage *)img angle:(double)angle;

- (void)playSound;

@end
