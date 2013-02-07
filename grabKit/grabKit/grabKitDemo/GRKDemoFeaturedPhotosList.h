//
//  GRKDemoFeaturedPhotosList.h
//  grabKit
//
//  Created by myeyesareblind on 2/7/13.
//
//

#import <UIKit/UIKit.h>
#import "GRKDemoPhotosList.h"
#import "GRKServiceFeaturedPhotosGrabberProtocol.h"

@class GRKServiceGrabber;
@interface GRKDemoFeaturedPhotosList : GRKDemoPhotosList {
    NSMutableArray* _photosFeedArray;
}

-(id) initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
           andGrabber:(GRKServiceGrabber*)grabber;

@end
