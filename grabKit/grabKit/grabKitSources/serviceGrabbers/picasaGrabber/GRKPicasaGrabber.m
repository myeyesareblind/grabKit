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


#import "GRKPicasaGrabber.h"
#import "GRKPicasaQuery.h"
#import "GRKPicasaConnector.h"
#import "GRKPicasaSingleton.h"
#import "GRKPicasaQueriesQueue.h"

#import "GDataServiceGooglePhotos+featuredFeed.h"
#import "GDataServiceGooglePhotos.h"
#import "GDataBaseElements.h"
#import "GRKComment.h"
#import "GRKCommentsInternalProtocol.h"

@interface GRKPicasaGrabber()
-(GRKAlbum *) albumFromGDataEntryPhotoAlbum:(GDataEntryPhotoAlbum *) entry;
-(GRKPhoto *) photoFromGDataEntryPhoto:(GDataEntryPhoto *) entry;
-(GDataQueryGooglePhotos *) photosQueryWithPhotosFeedURL:(NSURL*)feedURL
                                              pageOffset:(NSUInteger)pageOffset
                                   numberOfPhotosPerPage:(NSUInteger)photosPerPage;
@end


@implementation GRKPicasaGrabber


-(id) init {
    
    if ((self = [super initWithServiceName:kGRKServiceNamePicasa]) != nil){

        
    }     
    
    return self;
}


#pragma mark - GRKServiceGrabberConnectionProtocol methods

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) connectWithConnectionIsCompleteBlock:(GRKGrabberConnectionIsCompleteBlock)connectionIsCompleteBlock andErrorBlock:(GRKErrorBlock)errorBlock;
{
    
    // use a GRKPicasaConnector 
    __block GRKPicasaConnector * picasaConnector = [[GRKPicasaConnector alloc] initWithGrabberType:_serviceName];
    
    [picasaConnector  connectWithConnectionIsCompleteBlock:^(BOOL connected){

                    if ( connectionIsCompleteBlock != nil ){
                        dispatch_async(dispatch_get_main_queue(), ^{
                        connectionIsCompleteBlock(connected);
                        });
                    }
                    picasaConnector = nil;  
        
                } andErrorBlock:^(NSError * error){

                    if ( errorBlock != nil ){    
                        dispatch_async(dispatch_get_main_queue(), ^{
                        errorBlock(error);
                        });
                    }
                    picasaConnector = nil;
        
                }];
    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) disconnectWithDisconnectionIsCompleteBlock:(GRKGrabberDisconnectionIsCompleteBlock)disconnectionIsCompleteBlock;
{
    
    // use a GRKPicasaConnector 
    __block GRKPicasaConnector * picasaConnector = [[GRKPicasaConnector alloc] initWithGrabberType:_serviceName];
    
    [picasaConnector disconnectWithDisconnectionIsCompleteBlock:^(BOOL disconnected){
        
        if ( disconnectionIsCompleteBlock != nil ){
            dispatch_async(dispatch_get_main_queue(), ^{
            disconnectionIsCompleteBlock(disconnected);
            });
        }
        picasaConnector = nil;
        
    }];  
    
}

/* @see refer to GRKServiceGrabberConnectionProtocol documentation
 */
-(void) isConnected:(GRKGrabberConnectionIsCompleteBlock)connectedBlock;
{
    if ( connectedBlock == nil ) @throw NSInvalidArgumentException;
    
    // use a GRKPicasaConnector 
    __block GRKPicasaConnector * picasaConnector = [[GRKPicasaConnector alloc] initWithGrabberType:_serviceName];
    
    [picasaConnector isConnected:^(BOOL connected){
        
        dispatch_async(dispatch_get_main_queue(), ^{
        connectedBlock(connected);
        });
        picasaConnector = nil;
        
    }];
    
    
}


#pragma mark - GRKServiceGrabberProtocol methods

/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) albumsOfCurrentUserAtPageIndex:(NSUInteger)pageIndex
              withNumberOfAlbumsPerPage:(NSUInteger)numberOfAlbumsPerPage
                       andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock 
                          andErrorBlock:(GRKErrorBlock)errorBlock;
{

    
    if ( numberOfAlbumsPerPage > kGRKMaximumNumberOfAlbumsPerPage ) {
        
        NSException* exception = [NSException
                                  exceptionWithName:@"numberOfAlbumsPerPageTooHigh"
                                  reason:[NSString stringWithFormat:@"The number of albums per page you asked (%d) is too high", numberOfAlbumsPerPage]
                                  userInfo:nil];
        @throw exception;
    }

    
    // use pageIndex+1 because Picasa starts at page 1, and we start at page 0
	NSUInteger startIndex = (pageIndex * numberOfAlbumsPerPage)+1;
    NSMutableDictionary * paramsDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                				 [NSNumber numberWithInt:numberOfAlbumsPerPage], @"max-results", 
                                				 [NSNumber numberWithInt:startIndex], @"start-index",
                              			nil];
	
    
    NSString * userId = [GRKPicasaSingleton sharedInstance].userEmailAdress;
    
	NSURL *albumsBaseFeedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:userId
                                                                       albumID:nil 
                                                                     albumName:nil 
                                                                       photoID:nil 
                                                                          kind:@"album" 
                                                                        access:@"all"];
	
    __block GRKPicasaQuery * albumsQuery = nil;
   
    albumsQuery = [GRKPicasaQuery queryWithFeedURL:albumsBaseFeedURL 
                                  andParams:paramsDict
                          withHandlingBlock:^(GRKPicasaQuery *query, id result) {
                           
                              
                              if ( ! [result isKindOfClass:[GDataFeedPhotoUser class]] ){
                              
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
                              
                              NSMutableArray * albums = [NSMutableArray array];
                              for( GDataEntryPhotoAlbum * entry in [(GDataFeedPhotoUser *)result entries]){
                                  @autoreleasepool {
                                      GRKAlbum * album = [self albumFromGDataEntryPhotoAlbum:entry];
                                      [albums addObject:album];
                                  }
                              }
                              if ( completeBlock != nil ){
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                  completeBlock(albums);
                                  });
                              }
                              [self unregisterQueryAsLoading:albumsQuery];
                              albumsQuery = nil;
 
                          } andErrorBlock:^(NSError *error) {

                              if ( error.code == 404 && completeBlock != nil ){
                                  // If the user doesn't have a Picasa account, the error code is 404.
                                  // Let's NOT generate an error, let's consider the user has 0 album instead.
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                      completeBlock([NSMutableArray array]);
                                  });

                              } else  if ( errorBlock != nil ){
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
    
    NSString * userId = [GRKPicasaSingleton sharedInstance].userEmailAdress;

	NSURL *photosFeedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:userId
																   albumID:album.albumId 
																 albumName:nil 
																   photoID:nil 
																	  kind:nil 
																	access:nil];
    
    GDataQueryGooglePhotos * gDataPhotosQuery = [self photosQueryWithPhotosFeedURL:photosFeedURL
                                                                        pageOffset:pageIndex
                                                             numberOfPhotosPerPage:numberOfPhotosPerPage];
    __block GRKPicasaQuery * fillAlbumQuery = nil;
    
    fillAlbumQuery = [GRKPicasaQuery queryWithQuery:gDataPhotosQuery
                                  withHandlingBlock:^(GRKPicasaQuery *query, id result) {
                             
                              if ( ! [result isKindOfClass:[GDataFeedPhotoAlbum class]] ){

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
                              
							  NSMutableArray * newPhotos = [NSMutableArray array];
                              
                              for( GDataEntryPhoto * entry in [(GDataFeedPhotoAlbum *)result entries] ){
                                  
                                  @autoreleasepool {
                                      GRKPhoto * photo = [self photoFromGDataEntryPhoto:entry];
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

                              
                          } andErrorBlock:^(NSError *error) {
                              
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


-(void) fillCoverPhotoOfAlbums:(NSArray *)albums withCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock {
    
    
   // GDataServiceGooglePhotos * service = [GRKPicasaSingleton sharedInstance].service;
    
    NSString * userId = [GRKPicasaSingleton sharedInstance].userEmailAdress;
    
    NSString * sizes = @"32u,48u,64u,72u,104u,144u,150u,160u,94u,110u,128u,200u," 
    "220u,288u,320u,400u,512u,576u,640u,720u,800u,912u,1024u,1152u,1280u,1440u,1600u";
    
    
    
    
    GRKPicasaQueriesQueue * queriesQueue = [[GRKPicasaQueriesQueue alloc] init];
    
    for ( GRKAlbum * album in albums ){
    
        NSURL *photosFeedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:userId
                                                                       albumID:album.albumId 
                                                                     albumName:nil 
                                                                       photoID:nil 
                                                                          kind:nil 
                                                                        access:nil];
    

        __block GDataQueryGooglePhotos * photosQuery = [GDataQueryGooglePhotos queryWithFeedURL:photosFeedURL] ;
    
        // we want only one photo
        [photosQuery setStartIndex:1];
        [photosQuery setMaxResults:1];
    
        [photosQuery addCustomParameterWithName:@"thumbsize" value:sizes];
    
        NSLog(@" photo query at top : %@", photosQuery);
        
        __block GRKSubqueryResultBlock handlingBLockForThisQuery = ^id(id queue, id result, NSError *error) {
            
            // NSLog(@" result : %@", result);
            
            if ( [[(GDataFeedPhotoAlbum *)result entries] count] > 0 ){
                
                GDataEntryPhoto * firstEntry = [[(GDataFeedPhotoAlbum *)result entries] objectAtIndex:0];
                GRKPhoto * photo = [self photoFromGDataEntryPhoto:firstEntry];
                album.coverPhoto = photo;
                
                // if the album's cover has been set, return the album...
                return album;
            }
            
            // ... else, return nil. 
            // that way, in the final handling block of the queue, the results will contain all the updated albums
            return nil;
            
        };
        
        [queriesQueue addQuery:photosQuery 
                      withName:album.albumId
              andHandlingBlock:handlingBLockForThisQuery];
        
    }

    [queriesQueue performWithFinalBlock:^(id query, id results) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completeBlock(results);
        });
        
    }];
}


-(void) fillCoverPhotoOfAlbum:(GRKAlbum *)album andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock andErrorBlock:(GRKErrorBlock)errorBlock {
    
    [self fillCoverPhotoOfAlbums:[NSArray arrayWithObject:album] 
                withCompleteBlock:completeBlock 
                   andErrorBlock:errorBlock];
}

/*
-(void) commentsOfPhoto:(GRKPhoto *)photo
withCommentsAtPageIndex:(NSUInteger)pageIndex
withNumberOfCommentsPerPage:(NSUInteger)numberOfCommentsPerPage
       andCompleteBlock:(GRKServiceGrabberCompleteBlock)completeBlock
          andErrorBlock:(GRKErrorBlock)errorBlock {
    NSLog(@"Comments api are not implemented for picasa");

    NSString * userId = [GRKPicasaSingleton sharedInstance].userEmailAdress;
    NSURL* commentsFeedURL = [GDataServiceGooglePhotos photoFeedURLForUserID:userId
                                                                     albumID:nil//@"5747564028800324401"
                                                                   albumName:nil
                                                                     photoID:photo.photoId
                                                                        kind:@"comment"
                                                                      access:@"all"];
     This feed does work as expected, returns all the required fields.
     Unfortunately, there is no GDataComment or some sort of that, so the comments are not parsed.
     One would need to patch GData to add new model types and parsing.
} */

/*
GData expects feed to be included into album, not the raw array, the result is unparsed

-(void)featuredPhotosAtPageIndex:(NSUInteger)pageOffset
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
    
    NSURL *photosFeedURL = [GDataServiceGooglePhotos featuredPhotosFeed];
    GDataQueryGooglePhotos * gDataPhotosQuery = [self photosQueryWithPhotosFeedURL:photosFeedURL
                                                                        pageOffset:pageOffset
                                                             numberOfPhotosPerPage:numberOfPhotosPerPage];
    __block GRKPicasaQuery * featuredPhotosQuery = nil;
    GRKQueryResultBlock queryResultBlock = ^(id query, id result) {
GDataFeedBase 0x1262b5c0: {v:2.0 entries:500 etag:W/"D0ABQX0yfyp7ImA9WhBTEUo." updated:2013-02-06T18:35:50Z links:feed,self,next id:https://photos.googleapis.com/data/feed/featured unparsed:<gphoto:crowded_length>}
        if ( ! [result isKindOfClass:[GDataFeedPhotoAlbum class]] ){
            
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
        
        NSMutableArray * newPhotos = [NSMutableArray array];
        
        for( GDataEntryPhoto * entry in [(GDataFeedPhotoAlbum *)result entries] ){
            
            @autoreleasepool {
                GRKPhoto * photo = [self photoFromGDataEntryPhoto:entry];
                [newPhotos addObject:photo];
            }
            
        }
        
        if ( completeBlock != nil ){
            dispatch_async(dispatch_get_main_queue(), ^{
                completeBlock(newPhotos);
            });
        }
        [self unregisterQueryAsLoading:featuredPhotosQuery];
        featuredPhotosQuery = nil;

    };
    
    GRKErrorBlock queryErroBlock = ^(NSError* error) {
        if ( errorBlock != nil ){
            NSError * GRKError = [self errorForFeaturedPhotosOperationWithOriginalError:error];
            dispatch_async(dispatch_get_main_queue(), ^{
                errorBlock(GRKError);
            });
            
        }
        [self unregisterQueryAsLoading:featuredPhotosQuery];
        featuredPhotosQuery = nil;
    };
    
    featuredPhotosQuery = [GRKPicasaQuery queryWithQuery:gDataPhotosQuery
                                       withHandlingBlock:queryResultBlock
                                           andErrorBlock:queryErroBlock];
    
    [self registerQueryAsLoading:featuredPhotosQuery];
    [featuredPhotosQuery perform];
}
*/



/* @see refer to GRKServiceGrabberProtocol documentation
 */
-(void) cancelAll {
    
    NSArray * queriesToCancel = [NSArray arrayWithArray:_queries];
    
    for( GRKPicasaQuery * query in queriesToCancel ){
        
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
-(GDataQueryGooglePhotos *) photosQueryWithPhotosFeedURL:(NSURL*)feedURL
                                              pageOffset:(NSUInteger)pageOffset
                                   numberOfPhotosPerPage:(NSUInteger)photosPerPage {
    // use pageIndex+1 because Picasa starts at page 1, and we start at page 0
	NSUInteger startIndex = (pageOffset * photosPerPage)+1;
    
  	NSString * sizes = @"32u,48u,64u,72u,104u,144u,"
    "150u,160u,94u,110u,128u,200u,"
    "220u,288u,320u,400u,512u,576u,"
    "640u,720u,800u,912u,1024u,"
    "1152u,1280u,1440u,1600u";
    
    
    GDataQueryGooglePhotos * gDataPhotosQuery = [GDataQueryGooglePhotos queryWithFeedURL:feedURL];
    
    // we want only one photo
    [gDataPhotosQuery setStartIndex:startIndex];
    [gDataPhotosQuery setMaxResults:photosPerPage];
    [gDataPhotosQuery addCustomParameterWithName:@"thumbsize" value:sizes];
    return gDataPhotosQuery;
}


/** Build and return a GRKAlbum from the given GDataEntryPhotoAlbum.
 
 @param entry a GDataEntryPhotoAlbum representing the album to build, as returned by Picasa's API
 @return a GRKAlbum
 */
-(GRKAlbum *) albumFromGDataEntryPhotoAlbum:(GDataEntryPhotoAlbum *) entry;
{
	
	NSString * albumName = [(GDataAtomTitle *)[entry title] stringValue] ;
	NSString * albumId = [entry GPhotoID] ;
	NSDate * dateUpdated = [[(GDataEntryPhotoAlbum *)entry updatedDate] date]; 
	NSUInteger photosCount = [[entry photosUsed] integerValue];
	
    NSMutableDictionary * dates = [NSMutableDictionary dictionary];
	if ( dateUpdated != nil )
        [dates setObject:dateUpdated forKey:kGRKAlbumDatePropertyDateUpdated];
    
    
    GRKAlbum * album = [GRKAlbum albumWithId:albumId 
                                   andName:albumName 
                                  andCount:photosCount 
                       /*andPhotos:nil*/
                                  andDates:dates];
    
	return album;
	
}


/** Build and return a GRKPhoto from the given GDataEntryPhoto.
 
 @param entry a GDataEntryPhoto representing the photo to build, as returned by Picasa's API
 @return a GRKPhoto
 */
-(GRKPhoto *) photoFromGDataEntryPhoto:(GDataEntryPhoto *) entry;
{
	
	NSString * photoName = [[entry title] stringValue] ;
    NSString * photoCaption = [[[entry mediaGroup] mediaDescription] stringValue];
	NSString * photoId = [entry GPhotoID] ;
    

	NSTimeInterval dateTakenTimestamp = [[entry timestamp] doubleValue]; 
	NSDate * dateTaken = [NSDate dateWithTimeIntervalSince1970:dateTakenTimestamp];
    
	NSUInteger originalImageWidth = [[entry width] intValue];
	NSUInteger originalImageHeight = [[entry height] intValue];
    
    NSArray * rawThumbnails = [[entry mediaGroup] mediaThumbnails];
	
    NSMutableDictionary * dates = [NSMutableDictionary dictionary];
	if ( dateTaken != nil )
        [dates setObject:dateTaken forKey:kGRKPhotoDatePropertyDateTaken];
                                   
                            	
    
    NSMutableArray * images = [NSMutableArray arrayWithCapacity:[rawThumbnails count]];
	for( GDataMediaThumbnail * tn in rawThumbnails ){
		@autoreleasepool {
            NSUInteger imageWidth = [[tn width] intValue];
            NSUInteger imageHeight = [[tn height] intValue];
            BOOL isOriginal = (imageWidth == originalImageWidth && imageHeight == originalImageHeight);
            
            GRKImage * image = [GRKImage imageWithURLString:[tn URLString] 
                                                   andWidth:imageWidth
                                                  andHeight:imageHeight
                                                 isOriginal:isOriginal];
            [images addObject:image];            
        }
    }
    
    GRKPhoto * photo = [GRKPhoto photoWithId:photoId 
                                   andCaption:photoCaption 
                                   andName:photoName 
                                 andImages:images
                                  andDates:dates];

	return photo;
	
}



@end
