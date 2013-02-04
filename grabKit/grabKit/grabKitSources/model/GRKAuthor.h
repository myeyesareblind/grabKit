//
//  GRKAuthor.h
//  grabKit
//
//  Created by myeyesareblind on 1/29/13.
//
//

#import <Foundation/Foundation.h>

@interface GRKAuthor : NSObject {
}

-(id)initWithAuthorID:(NSString*)authorID
              andName:(NSString*)name;

@property (nonatomic, strong, readwrite) NSString* authorId;
@property (nonatomic, strong, readwrite) NSString* name;

@end
