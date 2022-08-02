#import "TaskManagerPlugin.h"
#if __has_include(<task_manager/task_manager-Swift.h>)
#import <task_manager/task_manager-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "task_manager-Swift.h"
#endif

@implementation TaskManagerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftTaskManagerPlugin registerWithRegistrar:registrar];
}
@end
