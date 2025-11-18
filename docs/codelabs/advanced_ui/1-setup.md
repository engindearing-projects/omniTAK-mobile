# Advanced UI

In this codelab you will learn a handful of advanced UI topics.

This example relies on components from the [Valdi_Widgets][Valdi_Widgets setup] library. You will need to update your `WORKSPACE` to use this library:

```starlark
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "valdi_widgets",
    branch = "main",
    remote = "git@github.com:Snapchat/Valdi_Widgets.git",
)
```

## Setup `HelloWorld.tsx`

Let's clear out [`HelloWorld.tsx`](../../../apps/helloworld/src/valdi/hello_world/src/HelloWorldApp.tsx) so we have a clean slate to work with.


It should look like

```tsx
import { Component } from 'valdi_core/src/Component';

import { onRootComponentCreated } from './CppModule';

/**
 * @ViewModel
 * @ExportModel
 */
export interface ViewModel {}

/**
 * @Context
 * @ExportModel
 */
export interface ComponentContext {}

/**
 * @Component
 * @ExportModel
 */
export class App extends Component<ViewModel, ComponentContext> {
  onCreate(): void {
    onRootComponentCreated(this.renderer.contextId);
  }

  onRender(): void {
    <view backgroundColor="white">
    </view>;
  }
}

```

## Make sure it loads

Connect a device or open an Android Emulator or iOS Simulator.

Start up the hotreloader.

```
cd apps/helloworld
valdi hotreload
```

Choose the `//apps/helloworld:hello_world_hotreload` target.

```
 valdi hotreload
 Running Bazel command: bazel query "attr(\"tags\", \"valdi_application\", //...)"
? Please choose a target to hot reload: (Use arrow keys)
 1. //apps/helloworld:hello_world_hotreload 
  2. //apps/navigation_example:navigation_example_app_hotreload 
  3. //apps/valdi_gpt:valdi_gpt_hotreload 
```

You should see a blank screen. If you don't, check the hotreloader for errors.

If you do see errors, check out the [**Getting help**](../how_to_get_help.md) section.


## Advanced UI topics
- [SectionList](./2-section_list.md)
- [FlexBox Layout](./3-flexbox.md)


[Valdi_Widgets setup]: https://github.com/Snapchat/Valdi_Widgets?tab=readme-ov-file#setup-valdi_widgets
