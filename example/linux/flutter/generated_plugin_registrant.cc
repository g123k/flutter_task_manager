//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <task_manager/task_manager_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) task_manager_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "TaskManagerPlugin");
  task_manager_plugin_register_with_registrar(task_manager_registrar);
}
