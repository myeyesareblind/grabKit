/*
 * This file is part of the GrabKit package.
 * Copyright (c) 2012 Pierre-Olivier Simonard <pierre.olivier.simonard@gmail.com>
 *  
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
 * associated documentation files (the "Software"), to deal in the Software without restriction, including 
 * without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
 * copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the 
 * following conditions:
 *  
 * The above copyright notice and this permission notice shall be included in all copies or substantial 
 * portions of the Software.
 *  
 * The Software is provided "as is", without warranty of any kind, express or implied, including but not 
 * limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no
 * event shall the authors or copyright holders be liable for any claim, damages or other liability, whether
 * in an action of contract, tort or otherwise, arising from, out of or in connection with the Software or the 
 * use or other dealings in the Software.
 *
 * Except as contained in this notice, the name(s) of (the) Author shall not be used in advertising or otherwise
 * to promote the sale, use or other dealings in this Software without prior written authorization from (the )Author.
 */

#import "GRKInstagramGrabber.h"
#import "GRKServiceGrabberProtocol.h"
#import "GRKInstagramQuery.h"
#import "GRKAlbum.h"
#import "GRKConstants.h"
#import "GRKComment.h"
#import "GRKAuthor.h"
#import "GRKCommentsInternalProtocol.h"

// instagram returns max 16 images of media/popular as of now, but it might change
const NSInteger FEATURED_ALBUM_MAX_PHOTOS_COUNT = 1000;


@interface GRKInstagramGrabber()<GRKCommentsInternalProtocol> {
}

// I use it to retrieve the last photo id to support pagination
@property (nonatomic, readonly) GRKAlbum* featuredAlbum;

-(BOOL) isResultForAlbumsInTheExpectedFormat:(id)result;

-(BOOL) isResultForPhotosInTheExpectedFormat:(id)result;

-(GRKPhoto *) photoWithRawPhoto:(NSDictionary*)rawPhoto;

-(GRKImage *) imageWithRawImage:(NSDictionary*)rawImage isOriginal:(BOOL)isOriginal;

-(void)resetAndRebuildConnector;

@end


@implementation GRKInstagramGrabber
@synthesize featuredAlbum = _featuredAlbum;


-(id) init {
    
    if ((self = [super initWithServiceName:kGRKServiceNameInstagram]) != nil){
        
    }     
    
    return self;
}


-(GRKAlbum*) featuredAlbum {
    if (!_featuredAlbum) {
        _featuredAlbum = [[GRKAlbum alloc] initWithId:@"0"
                                              andName:@"featuredPhotos"
                                             andCount:FEATURED_ALBUM_MAX_PHOTOS_COUNT
                                             andDates:0];
    }
    return _featuredAlbum;
}

#pragma mark - GRKServiceGrabberConnectionProtocol methods


/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) connectWithConnectionIsCompleteBlock:(GRKGrabberConnectionIsCompleteBlock)connectionIsCompleteBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
  
    // use a GRKInstagramConnector
    [self resetAndRebuildConnector];
        
    [instagramConnector connectWithConnectionIsCompleteBlock:^(BOOL connected){
        
                      if ( connectionIsCompleteBlock != nil ){
                          dispatch_async(dispatch_get_main_queue(), ^{
                          connectionIsCompleteBlock(connected);
                          });
                      }
                    instagramConnector = nil;
        
                  } andErrorBlock:^(NSError * error){
        
                      if ( errorBlock != nil ){
                          dispatch_async(dispatch_get_main_queue(), ^{
                          errorBlock(error);            
                          });
                      }
                      instagramConnector = nil;
        
                  }];
    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void)disconnectWithDisconnectionIsCompleteBlock:(GRKGrabberDisconnectionIsCompleteBlock)disconnectionIsCompleteBlock;
{
    
    // use a GRKInstagramConnector
    [self resetAndRebuildConnector];
    
    [instagramConnector disconnectWithDisconnectionIsCompleteBlock:^(BOOL disconnected){
     
        if ( disconnectionIsCompleteBlock != nil ){
            dispatch_async(dispatch_get_main_queue(), ^{
            disconnectionIsCompleteBlock(disconnected);
            });
        }
        
        instagramConnector = nil;
        
    }];

    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) isConnected:(GRKGrabberConnectionIsCompleteBlock)connectedBlock;
{
    if ( connectedBlock == nil ) @throw NSInvalidArgumentException;
    
    // use a GRKInstagramGrabber
    [self resetAndRebuildConnector];
    
    [instagramConnector isConnected:^(BOOL connected){
        dispatch_async(dispatch_get_main_queue(), ^{
        connectedBlock(connected);
        });
        instagramConnector = nil;
        
    }];
    
    
}


#pragma mark GRKServiceGrabberProtocol methods

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) albumsOfCurrentUserAtPageIndex:(NSUInteger)pageIndex
             withNumberOfAlbumsPerPage:(NSUInteger)numberOfAlbumsPerPage
                      andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                         andErrorBlock:(GRKErrorBlock)errorBlock
{
    
    if ( numberOfAlbumsPerPage > kGRKMaximumNumberOfAlbumsPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfAlbumsPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of albums per page you asked (%d) is too high", numberOfAlbumsPerPage]
                                  userInfo:nil];
        @throw exception;
    }

    __block GRKInstagramQuery * albumsQuery = nil;
    
												
    NSString * endpoint = @"users/self";
    
    //#warning for dev only    
    //endpoint = @"users/980434";

    albumsQuery = [GRKInstagramQuery queryWithEndpoint:endpoint
                                 withParams:nil
                         withHandlingBlock:^(GRKInstagramQuery * query, id result){

                             
                             if ( ! [self isResultForAlbumsInTheExpectedFormat:result] ){
                                 if ( errorBlock != nil ){
                                     // Create an error for "bad format result" and call the errorBlock
                                     NSError * error = [self errorForBadFormatResultForAlbumsOperation];
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                         errorBlock(error);
                                     });
                                 }

                                 [self unregisterQueryAsLoading:albumsQuery];
                                 albumsQuery = nil;
                                 return;
                             }
                             
                             // On Instagram, people just post images, but they don't organize them as albums.
                             // So the result will be a NSMutableDictionary containg only one GRKAlbum
                             // its id and its name will be "self"
                             // it contains 0 date

                            NSNumber * count = [[[(NSDictionary *)result objectForKey:@"data"] objectForKey:@"counts"] objectForKey:@"media"];
                            GRKAlbum * mainAlbum = [GRKAlbum albumWithId:@"self" 
                                                               andName:@"self" 
                                                              andCount:[count intValue]
                                                             /*andPhotos:nil*/
                                                   andDates:nil];
                             
                             
                             NSArray * albums = [NSArray arrayWithObject:mainAlbum];
                             if ( completeBlock != nil ){
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                 completeBlock(albums);
                                 });
                             }
                             [self unregisterQueryAsLoading:albumsQuery];
                             albumsQuery = nil;
                             
                         }andErrorBlock:^(NSError * error){
                             
                             if ( errorBlock != nil ){
                                 NSError * GRKError = [self errorForAlbumsOperationWithOriginalError:error];
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                     errorBlock(GRKError);
                                 });
                             }
                             [self unregisterQueryAsLoading:albumsQuery];
                             albumsQuery = nil;
                             
                         }];
    [self registerQueryAsLoading:albumsQuery];
    [albumsQuery perform];
}


/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) fillAlbum:(GRKAlbum *)album
   withPhotosAtPageIndex:(NSUInteger)pageIndex
withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
         andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
            andErrorBlock:(GRKErrorBlock)errorBlock;
{
    if ( numberOfPhotosPerPage > kGRKMaximumNumberOfPhotosPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfPhotosPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of photos per page you asked (%d) is too high", numberOfPhotosPerPage]
                                  userInfo:nil];
        @throw exception;
    }
  
    // First, let's build the parameters for the query
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params setObject:[NSNumber numberWithInt:numberOfPhotosPerPage] forKey:@"count"];
    
    
    // Instagram doens't offer the option to ask for photos at some page.
    // we must provide a max_id parameter to make the method return 
    // media with a lower id (we fetch the feed backward, from the most recent images to the least recent ones)
    // So, before querying the API, let's check if the previous pages are already loaded
    // If not, we perform the errorBlock with a specific NSError
    if ( pageIndex > 0 ){

        NSArray * photosForPreviousPage = [album photosAtPageIndex:pageIndex-1 withNumberOfPhotosPerPage:numberOfPhotosPerPage];
        
        GRKPhoto * lastAddedPhoto = [photosForPreviousPage lastObject];
	      if ( [lastAddedPhoto isKindOfClass:[NSNull class]] ){
              
              // discontinuous grabbing error
              if ( errorBlock != nil ){
                  dispatch_async(dispatch_get_main_queue(), ^{
                  errorBlock(nil);      
                  });
              } 
  		      return;
          }
        
        if ( lastAddedPhoto == nil ){

            // discontinuous grabbing error
            if ( errorBlock != nil ){
                dispatch_async(dispatch_get_main_queue(), ^{
                errorBlock(nil);	 
                });
            }
            return;
        }
        
        
        [params setObject:lastAddedPhoto.photoId forKey:@"max_id"];
	
        
    }
    

    __block GRKInstagramQuery * fillAlbumQuery = nil;
	


    NSString * endpoint = @"users/self/media/recent";

	//#warning for dev only    
    //endpoint = @"users/980434/media/recent";
    
    fillAlbumQuery = [GRKInstagramQuery queryWithEndpoint:endpoint
                                     withParams:params
                              withHandlingBlock:^(GRKInstagramQuery * query, id result){
                                                                    
                                  if ( ! [self isResultForPhotosInTheExpectedFormat:result] ){
                                      
                                      if ( errorBlock != nil ){
                                          // Create an error for "bad format result" and call the errorBlock
                                          NSError * error = [self errorForBadFormatResultForFillAlbumOperationWithOriginalAlbum:album];
                                          dispatch_async(dispatch_get_main_queue(), ^{
                                              errorBlock(error);
                                          });
                                      }
                                      
                                      [self unregisterQueryAsLoading:fillAlbumQuery];
                                      fillAlbumQuery = nil;
                                      return;
                                  }

                                  
								  NSArray * rawPhotos = [(NSDictionary*)result objectForKey:@"data"];
                                  NSMutableArray * newPhotos = [NSMutableArray array];
                                 
                                  
                                  for ( NSDictionary * rawPhoto in  rawPhotos ){
                                      @autoreleasepool {
                                          GRKPhoto * photo = [self photoWithRawPhoto:rawPhoto];
                                          [newPhotos addObject:photo];
                                      }
                                  }
                                  
                                  [album addPhotos:newPhotos forPageIndex:pageIndex withNumberOfPhotosPerPage:numberOfPhotosPerPage];
                                  
                                  if ( completeBlock != nil ){
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                      completeBlock(newPhotos);
                                      });
                                  }
                                  [self unregisterQueryAsLoading:fillAlbumQuery];
                                  fillAlbumQuery = nil;
 
                              }andErrorBlock:^(NSError * error){
                                  
                                  if ( errorBlock != nil ){
                                      NSError * GRKError = [self errorForFillAlbumOperationWithOriginalError:error];
                                      dispatch_async(dispatch_get_main_queue(), ^{
                                          errorBlock(GRKError);
                                      });

                                  }

                                  [self unregisterQueryAsLoading:fillAlbumQuery];
                                  fillAlbumQuery = nil;

                              }];

    [self registerQueryAsLoading:fillAlbumQuery];
    [fillAlbumQuery perform];

    
}


-(void) fillCoverPhotoOfAlbum:(GRKAlbum *)album 
             andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
                andErrorBlock:(GRKErrorBlock)errorBlock {
    
    
    [self fillAlbum:album withPhotosAtPageIndex:0 withNumberOfPhotosPerPage:1 andCompleteBlock:^(id result) {
       
        if ( [result isKindOfClass:[NSArray class]] && [result count] > 0){
            
            album.coverPhoto = [result objectAtIndex:0];
            completeBlock( [NSArray arrayWithObject:album] );
            
        } else {
            completeBlock([NSArray array]);  
        }
        

    } andErrorBlock:^(NSError *error) {

        
        
    }];
    
}

// Shouldn't be called for more than one album, as Instagram doens't organize content in albums...
-(void) fillCoverPhotoOfAlbums:(NSArray *)albums
             withCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
                andErrorBlock:(GRKErrorBlock)errorBlock  {
    

    if ( [albums count] > 0 ){
    
        [self fillCoverPhotoOfAlbum:[albums objectAtIndex:0]
                   andCompleteBlock:^(id result) {
                       
                       completeBlock(result);
                       
                   } andErrorBlock:^(NSError *error) {
                       
                   }];
        
    }
    
}



-(void)resetAndRebuildConnector;
{
    [instagramConnector cancelAll];
    
    instagramConnector = [[GRKInstagramConnector alloc] initWithGrabberType:_serviceName];
    
}


-(void) commentsOfPhoto:(GRKPhoto *)photo
withCommentsAtPageIndex:(NSUInteger)pageIndex
withNumberOfCommentsPerPage:(NSUInteger)numberOfCommentsPerPage
      andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
         andErrorBlock:(GRKErrorBlock)errorBlock {
    
    if (numberOfCommentsPerPage > kGRKMaximumNumberOfCommentsPerPage) {
        NSException* exeption = [NSException exceptionWithName:@"numberOfCommentsPerPageTooHigh"
                                                        reason:[NSString stringWithFormat:@"The number of comments per page you asked (%d) exceeds maximum possible", numberOfCommentsPerPage]
                                                      userInfo:nil];
        @throw exeption;
    }
    
    NSString* endpoint = [NSString stringWithFormat:@"media/%@/comments", photo.photoId];
    __block GRKInstagramQuery* allCommentsQuery = nil;
    
    GRKQueryResultBlock queryCompleteBlock = ^(id query, id result) {
        if ( ! [self isResultForCommentsInTheExpectedFormat:result] ){
            
            if ( errorBlock != nil ){
                // Create an error for "bad format result" and call the errorBlock
                NSError * error = [self errorForBadFormatResultCommentsOperation];
                dispatch_async(dispatch_get_main_queue(), ^{
                    errorBlock(error);
                });
            }
            
            [self unregisterQueryAsLoading:allCommentsQuery];
            allCommentsQuery = nil;
            return;
        }
        /// no paging api provided, grab all comments and trim them
        NSArray*        rawComments     = [(NSDictionary*) result objectForKey:@"data"];
        
        NSUInteger      maxCommenetsIndex        = rawComments.count ? rawComments.count - 1: 0;
        NSUInteger      locationIndex   = pageIndex * numberOfCommentsPerPage;
        if (locationIndex > maxCommenetsIndex || rawComments.count == 0) {
            [self unregisterQueryAsLoading:query];
            dispatch_async(dispatch_get_main_queue(), ^{
                completeBlock([NSArray array]);
            });
            return ;
        }
        
        NSUInteger      length          = numberOfCommentsPerPage;
        NSUInteger      maxRequestIndex = locationIndex + length;
        NSInteger       remainingLength = maxRequestIndex > maxCommenetsIndex ?
        rawComments.count - locationIndex:
        length;
        
        
        NSRange         commentsRange   = NSMakeRange(locationIndex,
                                                      remainingLength);
        NSArray*        requestedComments = [rawComments subarrayWithRange:commentsRange];
        
        NSMutableArray* actualComments  = [NSMutableArray new];
        for (NSDictionary* rawComment in requestedComments){
            @autoreleasepool {
                GRKComment* comment = [self commentWithRawComment:rawComment];
                [actualComments addObject:comment];
            }
        }
        [self unregisterQueryAsLoading:query];
        allCommentsQuery = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completeBlock(actualComments);
        });
    };
    
    GRKErrorBlock queryErrorBlock = ^(NSError* error) {
        if (errorBlock) {
            errorBlock(error);
        }
        [self unregisterQueryAsLoading:allCommentsQuery];
        allCommentsQuery = nil;
    };
    

    allCommentsQuery =     [GRKInstagramQuery queryWithEndpoint:endpoint
                                                     withParams:nil
                                              withHandlingBlock:queryCompleteBlock
                                                  andErrorBlock:queryErrorBlock];
    [self registerQueryAsLoading:allCommentsQuery];
    [allCommentsQuery perform];
}


-(void) featuredPhotosAtPageIndex:(NSUInteger)pageOffset
        withNumberOfPhotosPerPage:(NSUInteger)numberOfPhotosPerPage
                 andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
                    andErrorBlock:(GRKErrorBlock)errorBlock {
    
    if ( numberOfPhotosPerPage > kGRKMaximumNumberOfPhotosPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfPhotosPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of photos per page you asked (%d) is too high", numberOfPhotosPerPage]
                                  userInfo:nil];
        @throw exception;
    }
    
    NSMutableDictionary * params = [NSMutableDictionary dictionary];
    [params setObject:[NSNumber numberWithInt:numberOfPhotosPerPage]
               forKey:@"count"];
    
    if ( pageOffset > 0 ){
        
        NSArray * photosForPreviousPage = [self.featuredAlbum photosAtPageIndex:pageOffset - 1
                                                      withNumberOfPhotosPerPage:numberOfPhotosPerPage];
        
        GRKPhoto * lastAddedPhoto = [photosForPreviousPage lastObject];
        if ( [lastAddedPhoto isKindOfClass:[NSNull class]] ){
            
            // discontinuous grabbing error
            if ( errorBlock != nil ){
                dispatch_async(dispatch_get_main_queue(), ^{
                    errorBlock(nil);
                });
            }
            return;
        }
        
        if ( lastAddedPhoto == nil ){
            
            // discontinuous grabbing error
            if ( errorBlock != nil ){
                dispatch_async(dispatch_get_main_queue(), ^{
                    errorBlock(nil);
                });
            }
            return;
        }
        
        
        [params setObject:lastAddedPhoto.photoId forKey:@"max_id"];
    }
    
    NSString * endpoint = @"media/popular";
    
    __block GRKInstagramQuery* featuredPhotosQuery = nil;
    __weak  GRKAlbum*          featuredAlbum       = self.featuredAlbum;

    GRKQueryResultBlock queryResultBlock = ^(id query, id result) {
        if ( ! [self isResultForPhotosInTheExpectedFormat:result] ){
            
            if ( errorBlock != nil ){
                // Create an error for "bad format result" and call the errorBlock
                NSError * error = [self errorForBadFormatResultForFeaturedPhotosOperation];
                dispatch_async(dispatch_get_main_queue(), ^{
                    errorBlock(error);
                });
            }
            
            [self unregisterQueryAsLoading:featuredPhotosQuery];
            featuredPhotosQuery = nil;
            return;
        }
        
        
        NSArray * rawPhotos = [(NSDictionary*)result objectForKey:@"data"];
        NSMutableArray * newPhotos = [NSMutableArray array];
        
        
        for ( NSDictionary * rawPhoto in  rawPhotos ){
            @autoreleasepool {
                GRKPhoto * photo = [self photoWithRawPhoto:rawPhoto];
                [newPhotos addObject:photo];
            }
        }
        
        [featuredAlbum addPhotos:newPhotos
                    forPageIndex:pageOffset
       withNumberOfPhotosPerPage:numberOfPhotosPerPage];
        
        if ( completeBlock != nil ){
            dispatch_async(dispatch_get_main_queue(), ^{
                completeBlock(newPhotos);
            });
        }
        [self unregisterQueryAsLoading:featuredPhotosQuery];
        featuredPhotosQuery = nil;
    };
    
    GRKErrorBlock queryErrorBlock = ^(NSError* error) {
        if ( errorBlock != nil ){
            NSError * GRKError = [self errorForFillAlbumOperationWithOriginalError:error];
            dispatch_async(dispatch_get_main_queue(), ^{
                errorBlock(GRKError);
            });
            
        }
        
        [self unregisterQueryAsLoading:featuredPhotosQuery];
        featuredPhotosQuery = nil;
    };

    featuredPhotosQuery = [GRKInstagramQuery queryWithEndpoint:endpoint
                                                    withParams:params
                                             withHandlingBlock:queryResultBlock
                                                 andErrorBlock:queryErrorBlock];
    
    [self registerQueryAsLoading:featuredPhotosQuery];
    [featuredPhotosQuery perform];
}

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAll {
    
    [instagramConnector cancelAll];
    
    NSArray * queriesToCancel = [NSArray arrayWithArray:_queries];
    
    for( GRKInstagramQuery * query in queriesToCancel ){
        
        [query cancel];
        [self unregisterQueryAsLoading:query];
    }
    
}

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAllWithCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock;
{
    [self cancelAll];
    if ( completeBlock != nil ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completeBlock(nil);
        });
    }
    
}

#pragma mark - Internal processing methods

/** Check if the given result for an album is in the expected format.
 @param result the data to check. 
 @return  a boolean value. if YES, the data are in the expected format.
 */
-(BOOL) isResultForAlbumsInTheExpectedFormat:(id)result;
{
    // check if the result has the expected format
    if ( ! [result isKindOfClass:[NSDictionary class]] ){
        return NO;
    }
    if ( [(NSDictionary *)result objectForKey:@"data"] == nil ){
        return NO;
    }
    
	return YES;
}

/** Check if the given result for an photo is in the expected format.
 @param result the data to check. 
 @return  a boolean value. if YES, the data are in the expected format.
 */
-(BOOL) isResultForPhotosInTheExpectedFormat:(id)result;
{
    // check if the result as the expected format, calls errorBlock if not.
    if ( ! [result isKindOfClass:[NSDictionary class]] ){
        return NO;
    }
    if ( [(NSDictionary *)result objectForKey:@"data"] == nil ){
        return NO;
    }
    
    return YES;
}


/** Build and return a GRKPhoto from the given dictionary.
 
 @param rawPhoto a NSDictionary representing the photo to build, as returned by Instagram's API
 @return a GRKPhoto
 */
-(GRKPhoto *) photoWithRawPhoto:(NSDictionary*)rawPhoto;
{
 	
    NSString * photoId = [rawPhoto objectForKey:@"id"];

    NSString * caption = @"";
    if ( ! [[rawPhoto objectForKey:@"caption"] isKindOfClass:[NSNull class]]){
		caption = [[rawPhoto objectForKey:@"caption"] objectForKey:@"text"];
    }

    
    

    NSMutableDictionary * dates = [NSMutableDictionary dictionary];
    
    if ( ! [[rawPhoto objectForKey:@"created_time"] isKindOfClass:[NSNull class]] ){

        // raw "date creation" stored as timestamps in the Instagram's result.     
	    NSTimeInterval dateTakenTimestamp = [[rawPhoto objectForKey:@"created_time"] doubleValue];
    	NSDate * dateTaken = [NSDate dateWithTimeIntervalSince1970:dateTakenTimestamp];
    
	    if ( dateTaken != nil ) 
    	    [dates setObject:dateTaken forKey:kGRKPhotoDatePropertyDateCreated];
        
    }

    NSMutableArray * imagesForThisPhoto = [NSMutableArray array];
    if ( [[rawPhoto objectForKey:@"images"] isKindOfClass:[NSDictionary class]] ) {
        
    	for( NSString * imageKey in [rawPhoto objectForKey:@"images"] ){
        
        	NSDictionary * rawImage = [[rawPhoto objectForKey:@"images"] objectForKey:imageKey];
    	    BOOL isOriginal = [imageKey isEqualToString:@"standard_resolution"];
	        GRKImage * image = [self imageWithRawImage:rawImage isOriginal:isOriginal];
   	     	if ( image != nil ){
                [imagesForThisPhoto addObject:image];
	        }
        
	    }
        
    }
    
    GRKPhoto * photo = [GRKPhoto photoWithId:photoId andCaption:caption andName:nil andImages:imagesForThisPhoto andDates:dates];
    return photo;
    
}


/** Build and return a GRKImage from the given dictionary.
 
 @param rawImage a NSDictionary representing the image to build, as returned by Instagram's API
 @param isOriginal a BOOL value to specify if the build GRKImage is original or not.
 @return a GRKImage
 */
-(GRKImage *) imageWithRawImage:(NSDictionary*)rawImage isOriginal:(BOOL)isOriginal;
{
    NSString * imageWidth = [rawImage objectForKey:@"width"];
    NSString * imageHeight = [rawImage objectForKey:@"height"];
    NSString * imageUrlString = [rawImage objectForKey:@"url"];                                          

    if (imageWidth == nil || imageHeight == nil || imageUrlString == nil ) {
        return nil;
    }

    GRKImage * image = [GRKImage imageWithURLString:imageUrlString 
                                         andWidth:[imageWidth intValue] 
                                        andHeight:[imageHeight intValue]
                                       isOriginal:isOriginal];
    return image;
}



-(BOOL) isResultForCommentsInTheExpectedFormat:(id)result {
    // check if the result as the expected format, calls errorBlock if not.
    if ( ! [result isKindOfClass:[NSDictionary class]] ){
        return NO;
    }
    if ( [(NSDictionary *)result objectForKey:@"data"] == nil ){
        return NO;
    }
    
    return YES;
}

/*
 Example:
 "data": [
 {
 "created_time": "1280780324",
 "text": "Really amazing photo!",
 "from": {
 "username": "snoopdogg",
 "profile_picture": "http://images.instagram.com/profiles/profile_16_75sq_1305612434.jpg",
 "id": "1574083",
 "full_name": "Snoop Dogg"
 },
 "id": "420"
 },
 */
-(GRKComment*)commentWithRawComment:(NSDictionary *)rawComment {
    NSDictionary* rawAuthor = [rawComment objectForKey:@"from"];
    GRKAuthor* author = [[GRKAuthor alloc] initWithAuthorID:[rawAuthor objectForKey:@"id"]
                                                    andName:[rawAuthor objectForKey:@"username"]];
    NSString* dateString = [rawComment objectForKey:@"created_time"];
    NSDate*   date       = [NSDate dateWithTimeIntervalSince1970:[dateString doubleValue]];
    GRKComment* comment = [[GRKComment alloc] initWithCommentID:[rawComment objectForKey:@"id"]
                                                        message:[rawComment objectForKey:@"text"]
                                                    publishDate:date
                                                  commentAuthor:author];
    return comment;
}

@end
