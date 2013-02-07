//
//  GRKServiceFeaturedPhotosGrabberProtocol.h
//  grabKit
//
//  Created by myeyesareblind on 2/7/13.
//
//

#import <Foundation/Foundation.h>
#import "GRKServiceGrabberProtocol.h"


@protocol GRKServiceFeaturedPhotosGrabberProtocol <NSObject>

-(void) featuredPhotosAtPageIndex:(NSUInteger)pageOffset
        withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
                 andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                    andErrorBlock:(GRKErrorBlock)errorBlock;


@end
