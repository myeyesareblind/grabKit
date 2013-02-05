//
//  GDataQueryGooglePhotos+featuredFeed.m
//  grabKit
//
//  Created by myeyesareblind on 2/5/13.
//
//

#import "GDataQueryGooglePhotos+featuredFeed.h"
#import "GDataQueryGooglePhotos.h"

@implementation GDataQueryGooglePhotos (featuredFeed)

+(NSURL*) featuredPhotosFeed {
    NSString *root = [self serviceRootURLString];
    NSString* urlString = [NSString stringWithFormat:@"%@/feed/api/featured"];
    return [NSURL URLWithString:urlString];
}

@end
