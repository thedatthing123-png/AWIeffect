#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN
@interface AWIModelLoader : NSObject
+ (nullable SCNScene *)sceneAtURL:(NSURL *)url error:(NSError **)error NS_SWIFT_NAME(load(url:));
@end
NS_ASSUME_NONNULL_END
