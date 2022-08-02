#ifndef FLUTTER_PLUGIN_TASK_MANAGER_PLUGIN_H_
#define FLUTTER_PLUGIN_TASK_MANAGER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace task_manager {

class TaskManagerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  TaskManagerPlugin();

  virtual ~TaskManagerPlugin();

  // Disallow copy and assign.
  TaskManagerPlugin(const TaskManagerPlugin&) = delete;
  TaskManagerPlugin& operator=(const TaskManagerPlugin&) = delete;

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace task_manager

#endif  // FLUTTER_PLUGIN_TASK_MANAGER_PLUGIN_H_
