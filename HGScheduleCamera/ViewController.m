//
//  ViewController.m
//  HGScheduleCamera
//
//  Created by HamGuy on 2024/5/21.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>

@interface ViewController ()<AVCapturePhotoCaptureDelegate>

@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCapturePhotoOutput *stillImageOutput;
@property (strong, nonatomic) NSTimer *photoTimer;

@property (nonatomic, assign) NSInteger totalCount;

@property (nonatomic, strong) IBOutlet UIButton *startButton;
@property (nonatomic, strong) IBOutlet UIButton *stopButton;
@property (nonatomic, strong) IBOutlet UIImageView *preViewImageView;
@property (nonatomic, strong) IBOutlet UILabel *statusLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupCamera];
    [self updateStatus:YES];
}

-(void)startTimer {
    __weak typeof(self) weakSelf = self;
    self.photoTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf takePhoto];
        } else {
            [timer invalidate];
        }
    }];
}

-(IBAction)startCapture:(id)sender {
    [self startTimer];
    [self updateStatus:NO];
}

-(IBAction)stopCapture:(id)sender {
    [self stopTimer];
    [self updateStatus:YES];
}

-(void)updateStatus:(BOOL)enableCapture {
    self.startButton.enabled = enableCapture;
    self.stopButton.enabled = !enableCapture;
    if(!enableCapture) {
        self.statusLabel.text = @"";
    }
}
 
-(void)stopTimer {
    [self.photoTimer invalidate];
    self.photoTimer = nil;
    self.totalCount = 0;
}

- (void)setupCamera {
    // 初始化 session 和 output
    self.session = [[AVCaptureSession alloc] init];
    self.stillImageOutput = [[AVCapturePhotoOutput alloc] init];
    
    // 设置分辨率
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    
    // 获取后置摄像头
    AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error:&error];
    
    if (!error) {
        // 配置 session
        if ([self.session canAddInput:input] && [self.session canAddOutput:self.stillImageOutput]) {
            [self.session addInput:input];
            [self.session addOutput:self.stillImageOutput];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.session startRunning];
            });
            
        }
    } else {
        NSLog(@"Error: %@", error.localizedDescription);
    }
}

- (void)takePhoto {
    AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
    [self.stillImageOutput capturePhotoWithSettings:settings delegate:self];
}

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (!error) {
        NSData *imageData = [photo fileDataRepresentation];
        UIImage *image = [UIImage imageWithData:imageData];
        
        self.preViewImageView.image = image;
        
        UIImage *timestampedImage = [self imageByAddingCurrentDateToImage:image];
        
        [self saveImageToPhotoAlbum:timestampedImage];
        
        self.totalCount += 1;
        
        self.statusLabel.text = [NSString stringWithFormat:@"当前拍摄照片数:%ld", self.totalCount];
    }
}

- (UIImage *)imageByAddingCurrentDateToImage:(UIImage *)image {
    UIGraphicsBeginImageContext(image.size);
    
    [image drawAtPoint:CGPointZero];
    
    NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterMediumStyle];
    NSDictionary *attributes = @{
        NSForegroundColorAttributeName: [self randomColor],
        NSFontAttributeName: [UIFont systemFontOfSize:128]
    };
    
    [timestamp drawAtPoint:CGPointMake(96, 96) withAttributes:attributes];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (UIColor *)randomColor {
    CGFloat red = arc4random() % 256 / 255.0;
    CGFloat green = arc4random() % 256 / 255.0;
    CGFloat blue = arc4random() % 256 / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (void)saveImageToPhotoAlbum:(UIImage *)image {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            } completionHandler:^(BOOL success, NSError * _Nullable error) {
                if (success) {
                    NSLog(@"图片已保存到相册");
                } else {
                    NSLog(@"保存图片到相册失败: %@", error);
                }
            }];
        } else {
            NSLog(@"应用没有权限访问相册，无法保存图片");
        }
    }];
}


@end
