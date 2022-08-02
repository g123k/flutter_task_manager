#include "include/task_manager/task_manager_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "task_manager_plugin.h"

void TaskManagerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  task_manager::TaskManagerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
