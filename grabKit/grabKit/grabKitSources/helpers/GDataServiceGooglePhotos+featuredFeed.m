//
//  GDataQueryGooglePhotos+featuredFeed.m
//  grabKit
//
//  Created by myeyesareblind on 2/5/13.
//
//

#import "GDataServiceGooglePhotos+featuredFeed.h"
#import "GDataServiceGoogle.h"

@implementation GDataServiceGooglePhotos (featuredFeed)

+(NSURL*) featuredPhotosFeed {
    NSString *rootString = [GDataServiceGooglePhotos serviceRootURLString];
    NSString* urlString = [NSString stringWithFormat:@"%@feed/api/featured", rootString];
    return [NSURL URLWithString:urlString];
}

@end
