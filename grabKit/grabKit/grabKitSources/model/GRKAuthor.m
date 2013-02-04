//
//  GRKAuthor.m
//  grabKit
//
//  Created by myeyesareblind on 1/29/13.
//
//

#import "GRKAuthor.h"

@implementation GRKAuthor

@synthesize authorId;
@synthesize name;


-(id)initWithAuthorID:(NSString*)authorID_
              andName:(NSString*)name_ {
    self = [super init];
    if (self) {
        self.authorId = authorID_;
        self.name     = name_;
    }
    return self;
}

-(NSString*)description{
    return [NSString stringWithFormat:@"%@ with ID:%@", name, authorId];
}

@end
