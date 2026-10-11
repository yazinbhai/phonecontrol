<template>
  <div class="scrcpy-container">
    <div :class="['content-wrapper', `fit-${fitClass}`]" ref="fullScreenContainer">
      <RenderContainer
        ref="renderRef"
        :classes="classes"
        :container-style="currentContainerStyle"
        @pointerdown="handlePointerDown"
        @pointermove="handlePointerMove"
        @pointerup="handlePointerUp"
        @pointercancel="handlePointerUp"
        @pointerleave="handlePointerLeave"
        @contextmenu="handleContextMenu"
        @wheel="handleWheel"
        @dblclick="toggleFullscreen"
      />

      <!-- Floating Coordinate Window -->
      <FloatingCoordinateWindow
        :visible="isCoordinateTrackingActive && isMouseInScreen"
        :mouse-x="currentMouseX"
        :mouse-y="currentMouseY"
        :absolute-x="currentAbsoluteX"
        :absolute-y="currentAbsoluteY"
        :device-width="getDeviceRealWidth()"
        :device-height="getDeviceRealHeight()"
      />
      <!-- Non-fullscreen Side Toolbar -->
      <transition name="sidebar-slide" appear>
        <div class="side-toolbar" v-if="!isLoading && !hasError && !isFullscreen && isSidebarVisible">
        <!-- Toolbar Collapse Button -->
        <div class="sidebar-toggle-top" @click="toggleSidebar">
          <el-tooltip content="Collapse Toolbar" placement="left">
            <el-icon :size="14">
              <ArrowDown />
            </el-icon>
          </el-tooltip>
        </div>
        <DeviceFunctionButton 
          :press-key="pressKey"
          :calc-width-and-height="calcWidthAndHeight"
          :is-fullscreen="isFullscreen"
          @toggle-fullscreen="toggleFullscreen"
          @toggle-visibility="toggleVisibility"
          @toggle-rotate="toggleRotate"
          @toggle-focus="toggleFocus"
          @toggle-notifications="toggleNotifications"
          @toggle-fit-mode="toggleFitMode"
        />
        </div>
      </transition>
      <!-- Fullscreen Side Toolbar -->
      <div class="fullscreen-side-controls" v-if="isFullscreen && !isLoading && !hasError">
        <DeviceFunctionButton 
          :press-key="pressKey"
          :calc-width-and-height="calcWidthAndHeight"
          :is-fullscreen="isFullscreen"
          @toggle-fullscreen="toggleFullscreen"
          @toggle-visibility="toggleVisibility"
          @toggle-rotate="toggleRotate"
          @toggle-focus="toggleFocus"
          @toggle-notifications="toggleNotifications"
          @toggle-fit-mode="toggleFitMode"
        />
      </div>
      <!-- Fullscreen Bottom Controls -->
      <div class="fullscreen-bottom-controls" v-if="isFullscreen && !isLoading && !hasError">
        <DeviceOperateButton
          :press-key="pressKey"
          :container-width="440"
          :is-fullscreen="isFullscreen"
          :fit-mode="fitMode"
          @toggle-fullscreen="toggleFullscreen"
          @set-fit-mode="setFitMode"
          @toggle-fit-mode="toggleFitMode"
          @apply-adb-mode="handleAdbMode"
          class="mt-1"
        />
      </div>
    </div>
    <LoadingScreen 
      v-if="isLoading"
      :message="loadingMessage"
      :sub-message="loadingSubMessage"
    />
    <div v-if="hasError" class="error-container">
      <div class="error-content">
        <h3>Connection Error</h3>
        <p>{{ connectionError }}</p>
        <button @click="retryConnection" class="retry-button">
          Retry Connection
        </button>
      </div>
    </div>
    <div class="bottom-control-container" v-if="!isFullscreen">
      <DeviceOperateButton
        :press-key="pressKey"
        :container-width="calcWidthAndHeight[0]"
        :is-fullscreen="isFullscreen"
        :fit-mode="fitMode"
        @toggle-fullscreen="toggleFullscreen"
        @set-fit-mode="setFitMode"
        @toggle-fit-mode="toggleFitMode"
        @apply-adb-mode="handleAdbMode"
        class="mt-1"
      />
      <!-- Sidebar Expand Button -->
      <div class="sidebar-expand-button" v-if="!isSidebarVisible" @click="toggleSidebar">
        <el-tooltip content="Show Toolbar" placement="top">
          <div class="expand-btn">
            <el-icon :size="14">
              <ArrowUp />
            </el-icon>
          </div>
        </el-tooltip>
      </div>
    </div>
  </div>
</template>

<script setup>
import {onMounted, onBeforeUnmount, ref, computed, watch} from 'vue';
import RenderContainer from './components/RenderContainer.vue';
import {useScrcpy} from './ScrcpyLogic.js';
import DeviceOperateButton from "@/pages/scrcpyShow/components/DeviceOperateButton.vue";
import DeviceFunctionButton from "@/pages/scrcpyShow/components/DeviceFunctionButton.vue";
import LoadingScreen from "@/pages/scrcpyShow/components/LoadingScreen.vue";
import FloatingCoordinateWindow from "@/pages/scrcpyShow/components/FloatingCoordinateWindow.vue";
import {
  AndroidKeyCode,
  AndroidMotionEventAction,
  AndroidMotionEventButton,
  ScrcpyPointerId
} from "@yume-chan/scrcpy";
import { ArrowUp, ArrowDown } from "@element-plus/icons-vue";
import { ElMessage } from 'element-plus';
import { executeCommand } from '@/utils/adbManager.js';

const renderRef = ref();
const isLoading = ref(true);
const loadingMessage = ref('Connecting to device...');
const loadingSubMessage = ref('Please wait a moment');
const fullScreenContainer = ref(null);
const isFullscreen = ref(false);
// Sidebar visibility state - visible by default
const isSidebarVisible = ref(true);
// 添加坐标跟踪状态
const isCoordinateTrackingActive = ref(false);
const isMouseInScreen = ref(false); // 鼠标是否在屏幕内
const currentMouseX = ref(0);
const currentMouseY = ref(0);
const currentAbsoluteX = ref(0);
const currentAbsoluteY = ref(0);

// 获取所有必要的变量和函数
const {
  width,
  height,
  windowWidth,
  windowHeight,
  openInput,
  containerStyle,
  classes,
  changeStyle,
  openKeyInput,
  swapWidthHeight,
  handleKeyEvent,
  handlePointerDown,
  handlePointerMove: originalHandlePointerMove,
  handlePointerUp,
  handlePointerLeave: originalHandlePointerLeave,
  handleContextMenu: originalHandleContextMenu,
  handleWheel,
  scrcpyStart,
  destroyClient,
  // 新增状态
  connectionStatus,
  connectionError,
  // 新增变量
  client,
  rotation,
  // 设备分辨率
  deviceRealWidth: getDeviceRealWidth,
  deviceRealHeight: getDeviceRealHeight,
  // 坐标转换函数
  clientPositionToDevicePosition
} = useScrcpy();

// Dynamic container style based on fullscreen mode
const currentContainerStyle = computed(() => {
  if (isFullscreen.value) {
    return {
      width: '100vw',
      height: '100vh',
      maxWidth: '100vw',
      maxHeight: '100vh',
      margin: '0',
      padding: '0',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundColor: '#000000',
      borderRadius: '0',
      overflow: 'hidden',
      transform: 'none',
      boxShadow: 'none',
      border: 'none',
    };
  }
  return containerStyle.value;
});

// 自定义鼠标移动处理函数，包装原始函数并添加坐标跟踪功能
const handlePointerMove = async (event) => {
  // 更新鼠标位置
  currentMouseX.value = event.clientX;
  currentMouseY.value = event.clientY;

  // 如果坐标跟踪模式激活，计算设备坐标
  if (isCoordinateTrackingActive.value) {
    // 获取渲染容器的位置和尺寸
    const container = renderRef.value?.renderContainer;
    if (container) {
      const rect = container.getBoundingClientRect();

      // 计算相对于容器的位置
      const relX = event.clientX - rect.left;
      const relY = event.clientY - rect.top;

      // 检查鼠标是否在容器范围内
      const isInBounds = relX >= 0 && relX <= rect.width && relY >= 0 && relY <= rect.height;
      isMouseInScreen.value = isInBounds;

      if (isInBounds) {
        // 计算相对于设备的坐标（0-1范围）
        let pointerViewX = relX / rect.width;
        let pointerViewY = relY / rect.height;

        // 根据旋转调整坐标
        let adjustedX = pointerViewX;
        let adjustedY = pointerViewY;

        // 处理旋转（与 adjustPositionForRotation 保持一致）
        if (rotation === 1) { // 90度
          [adjustedX, adjustedY] = [adjustedY, 1 - adjustedX];
        } else if (rotation === 2) { // 180度
          adjustedX = 1 - adjustedX;
          adjustedY = 1 - adjustedY;
        } else if (rotation === 3) { // 270度
          [adjustedX, adjustedY] = [1 - adjustedY, adjustedX];
        }

        // 计算设备上的绝对坐标 - 使用设备真实分辨率
        const deviceWidth = getDeviceRealWidth();
        const deviceHeight = getDeviceRealHeight();
        currentAbsoluteX.value = Math.round(adjustedX * deviceWidth);
        currentAbsoluteY.value = Math.round(adjustedY * deviceHeight);
      }
    }
  }

  // 调用原始的处理函数
  await originalHandlePointerMove(event);
};

// 自定义鼠标离开处理函数
const handlePointerLeave = async (event) => {
  // 如果坐标跟踪模式激活，隐藏坐标窗口
  if (isCoordinateTrackingActive.value) {
    // 设置鼠标不在屏幕内，这会隐藏坐标窗口
    isMouseInScreen.value = false;
  }

  // 调用原始的处理函数
  await originalHandlePointerLeave(event);
};

// 自定义右键事件处理函数
const handleContextMenu = async (event) => {
  // 如果坐标跟踪模式激活，则复制坐标而不是调用原始处理函数
  if (isCoordinateTrackingActive.value) {
    event.preventDefault();
    event.stopPropagation();

    // 复制相对坐标
    await copyCoordinatesToClipboard();
  } else {
    // 否则调用原始的右键处理函数
    await originalHandleContextMenu(event);
  }
};

// 复制坐标到剪贴板的函数
const copyCoordinatesToClipboard = async () => {
  try {
    const deviceWidth = getDeviceRealWidth();
    const deviceHeight = getDeviceRealHeight();

    // 计算相对坐标
    const relativeX = deviceWidth > 0 ? currentAbsoluteX.value / deviceWidth : 0;
    const relativeY = deviceHeight > 0 ? currentAbsoluteY.value / deviceHeight : 0;

    const relativeCoords = `${relativeX.toFixed(3)}, ${relativeY.toFixed(3)}`;

    await navigator.clipboard.writeText(relativeCoords);

    ElMessage.success({
      message: `✅ Coordinates copied to clipboard: (${relativeCoords})`,
      duration: 3000,
      showClose: true
    });
  } catch (error) {
    console.error('Failed to copy to clipboard:', error);

    // Fallback copy method
    try {
      const deviceWidth = getDeviceRealWidth();
      const deviceHeight = getDeviceRealHeight();
      const relativeX = deviceWidth > 0 ? currentAbsoluteX.value / deviceWidth : 0;
      const relativeY = deviceHeight > 0 ? currentAbsoluteY.value / deviceHeight : 0;
      const relativeCoords = `${relativeX.toFixed(3)}, ${relativeY.toFixed(3)}`;

      const textArea = document.createElement('textarea');
      textArea.value = relativeCoords;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);

      ElMessage.success({
        message: `✅ Coordinates copied to clipboard: (${relativeCoords})`,
        duration: 3000,
        showClose: true
      });
    } catch (fallbackError) {
      ElMessage.error({
        message: '❌ Failed to copy coordinates to clipboard',
        duration: 3000,
        showClose: true
      });
    }
  }
};

const calcWidthAndHeight = computed(() => {
  const [calcWidth, calcHeight] = swapWidthHeight(width.value, height.value)
  return [calcWidth, calcHeight]
})

const pressKey = (event, type) => {
  console.log('Event:', event);  // 原生事件
  console.log('Type:', type, AndroidKeyCode[type]);     // 自定义参数
  handleKeyEvent(event, AndroidKeyCode[type]);
};

// 切换侧边栏显示状态
const toggleSidebar = () => {
  isSidebarVisible.value = !isSidebarVisible.value;
  console.log('切换侧边栏显示状态:', isSidebarVisible.value);
};

// Toggle Fullscreen mode
const toggleFullscreen = () => {
  if (!document.fullscreenElement) {
    if (fullScreenContainer.value?.requestFullscreen) {
      fullScreenContainer.value.requestFullscreen().catch((err) => {
        console.error(`Failed to enter fullscreen: ${err.message}`);
      });
    }
  } else {
    if (document.exitFullscreen) {
      document.exitFullscreen().catch((err) => {
        console.error(`Failed to exit fullscreen: ${err.message}`);
      });
    }
  }
};

// Screen Mode: 'fill' (stretch - removes black bars), '20:9' (native phone ratio), '11.6' (16:9 widescreen)
const fitMode = ref('fill');

const fitClass = computed(() => {
  if (fitMode.value === '20:9') return '20-9';
  if (fitMode.value === '11.6') return '11-6';
  return 'fill';
});

const applyCanvasFitMode = (mode) => {
  const canvas = renderRef.value?.renderContainer?.querySelector('canvas');
  if (canvas && isFullscreen.value) {
    if (mode === 'fill') {
      canvas.style.objectFit = 'fill';
      canvas.style.width = '100vw';
      canvas.style.height = '100vh';
      canvas.style.maxWidth = '100vw';
      canvas.style.maxHeight = '100vh';
      canvas.style.aspectRatio = '';
    } else if (mode === '20:9') {
      canvas.style.objectFit = 'contain';
      canvas.style.width = 'auto';
      canvas.style.height = 'auto';
      canvas.style.maxWidth = '100vw';
      canvas.style.maxHeight = '100vh';
      canvas.style.aspectRatio = '';
    } else if (mode === '11.6') {
      canvas.style.objectFit = 'fill';
      canvas.style.width = '100vw';
      canvas.style.height = '100vh';
      canvas.style.maxWidth = '100vw';
      canvas.style.maxHeight = '100vh';
      canvas.style.aspectRatio = '16 / 9';
    }
  }
};

const setFitMode = (mode) => {
  fitMode.value = mode;
  applyCanvasFitMode(mode);
  
  if (mode === '20:9') {
    ElMessage.info({
      message: '📱 Display Mode: 20:9 (Native Phone Ratio - 2400×1080)',
      duration: 2500,
      showClose: true
    });
  } else if (mode === '11.6') {
    ElMessage.info({
      message: '💻 Display Mode: 11.6" Screen (16:9 Widescreen Format)',
      duration: 2500,
      showClose: true
    });
  } else {
    ElMessage.success({
      message: '🖥️ Display Mode: Fill (Edge-to-Edge - No Black Bars)',
      duration: 2500,
      showClose: true
    });
  }
};

const toggleFitMode = () => {
  if (fitMode.value === 'fill') {
    setFitMode('20:9');
  } else if (fitMode.value === '20:9') {
    setFitMode('11.6');
  } else {
    setFitMode('fill');
  }
};

const handleAdbMode = async (action) => {
  try {
    if (action === '11.6') {
      const isLandscape = width.value > height.value;
      const targetRes = isLandscape ? '1920x1080' : '1080x1920';
      await executeCommand(`wm size ${targetRes}`);
      ElMessage.success({
        message: `💻 Phone resolution adapted for 11.6" screen (${targetRes})`,
        duration: 3500,
        showClose: true
      });
      setFitMode('11.6');
    } else if (action === 'reset') {
      await executeCommand('wm size reset');
      ElMessage.success({
        message: '🔄 Phone resolution reset to native 20:9 (2400×1080)',
        duration: 3500,
        showClose: true
      });
      setFitMode('20:9');
    }
  } catch (error) {
    console.error('ADB Resolution command failed:', error);
    ElMessage.error({
      message: 'Failed to update phone resolution: ' + (error.message || 'Error'),
      duration: 3000,
      showClose: true
    });
  }
};

// Update sidebar position in fullscreen mode
const updateSidebarPosition = () => {
  const canvas = renderRef.value?.renderContainer?.querySelector('canvas');
  const sidebar = document.querySelector('.fullscreen-side-controls');
  
  if (canvas && sidebar) {
    const canvasRect = canvas.getBoundingClientRect();
    const rightPosition = canvasRect.right + 16;
    
    // Only adjust left position if it stays inside the viewport
    if (rightPosition + 60 < window.innerWidth) {
      sidebar.style.left = `${rightPosition}px`;
      sidebar.style.right = 'auto';
    } else {
      sidebar.style.left = 'auto';
      sidebar.style.right = '16px';
    }
  }
};

const toggleVisibility = () => {
  console.log('切换可见性');
  // 实现可见性切换功能
  if (renderRef.value && renderRef.value.renderContainer) {
    const container = renderRef.value.renderContainer;
    if (container.style.visibility === 'hidden') {
      container.style.visibility = 'visible';
    } else {
      container.style.visibility = 'hidden';
    }
  }
};

const toggleRotate = () => {
  console.log('旋转屏幕');
  // 实现屏幕旋转功能
  if (client) {
    // 尝试获取渲染器元素
    const renderer = document.querySelector('.video');
    if (renderer) {
      // 通过样式修改实现旋转效果
      const currentTransform = renderer.style.transform || '';
      if (currentTransform.includes('rotate(90deg)')) {
        renderer.style.transform = currentTransform.replace('rotate(90deg)', 'rotate(180deg)');
      } else if (currentTransform.includes('rotate(180deg)')) {
        renderer.style.transform = currentTransform.replace('rotate(180deg)', 'rotate(270deg)');
      } else if (currentTransform.includes('rotate(270deg)')) {
        renderer.style.transform = currentTransform.replace('rotate(270deg)', '');
      } else {
        renderer.style.transform = currentTransform + ' rotate(90deg)';
      }
    }
  }
};

const toggleFocus = () => {
  console.log('切换坐标跟踪模式');
  isCoordinateTrackingActive.value = !isCoordinateTrackingActive.value;

  if (isCoordinateTrackingActive.value) {
    console.log('坐标跟踪模式已启用');
  } else {
    console.log('坐标跟踪模式已禁用');
  }
};

const toggleNotifications = async () => {
  console.log('切换通知');
  // 实现通知切换功能 - 打开/关闭安卓通知栏
  if (client && client.controller) {
    try {
      // 发送下拉通知栏的手势
      await client.controller.injectSwipe({
        pointerId: ScrcpyPointerId.MOUSE,
        action: AndroidMotionEventAction.DOWN,
        buttons: AndroidMotionEventButton.Primary,
        position: { x: deviceRealWidth / 2, y: 10 },
        pressure: 1,
      });
      
      await new Promise(resolve => setTimeout(resolve, 10));
      
      await client.controller.injectSwipe({
        pointerId: ScrcpyPointerId.MOUSE,
        action: AndroidMotionEventAction.MOVE,
        buttons: AndroidMotionEventButton.Primary,
        position: { x: deviceRealWidth / 2, y: deviceRealHeight / 4 },
        pressure: 1,
      });
      
      await new Promise(resolve => setTimeout(resolve, 10));
      
      await client.controller.injectSwipe({
        pointerId: ScrcpyPointerId.MOUSE,
        action: AndroidMotionEventAction.UP,
        buttons: AndroidMotionEventButton.Primary,
        position: { x: deviceRealWidth / 2, y: deviceRealHeight / 4 },
        pressure: 0,
      });
    } catch (error) {
      console.error('通知栏操作失败:', error);
    }
  }
};

// 计算是否有错误
const hasError = computed(() => connectionStatus.value === 'error');

// Reconnect
const retryConnection = async () => {
  isLoading.value = true;
  loadingMessage.value = 'Reconnecting...';
  loadingSubMessage.value = 'Please wait a moment';
  
  try {
    await destroyClient();
    setTimeout(async () => {
      await scrcpyStart(renderRef.value);
    }, 1000);
  } catch (error) {
    console.error("Retry connection failed:", error);
  }
};

// Listen for window changes
watch([windowWidth, windowHeight], ([newWidth, newHeight]) => {
  if (width.value !== 0 || height.value !== 0) {
    changeStyle()
  }
});

// Listen for screen render state
watch([width, height], ([newWidth, newHeight]) => {
  if (newWidth > 0 && newHeight > 0) {
    setTimeout(() => {
      loadingMessage.value = 'Device connected successfully';
      loadingSubMessage.value = 'Preparing screen display...';
      
      setTimeout(() => {
        isLoading.value = false;
      }, 500);
    }, 500);
  }
});

// 监听连接状态
watch(connectionStatus, (newStatus) => {
  console.log('连接状态变化:', newStatus);
  
  switch (newStatus) {
    case 'idle':
      // 初始状态，不做特殊处理
      break;
    case 'connecting':
      isLoading.value = true;
      loadingMessage.value = 'Connecting to device...';
      loadingSubMessage.value = 'Please wait a moment';
      break;
    case 'connected':
      loadingMessage.value = 'Device connected successfully';
      loadingSubMessage.value = 'Loading display stream...';
      break;
    case 'error':
      loadingMessage.value = 'Connection error';
      loadingSubMessage.value = connectionError;
      setTimeout(() => {
        isLoading.value = false;
      }, 1500);
      break;
  }
});


// Handle Fullscreen state changes
const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement;
  const canvas = renderRef.value?.renderContainer?.querySelector('canvas');
  
  if (isFullscreen.value) {
    if (canvas) {
      canvas.style.maxWidth = '100vw';
      canvas.style.maxHeight = '100vh';
      canvas.style.borderRadius = '0px';
      canvas.style.boxShadow = 'none';
      canvas.style.border = 'none';
      canvas.style.margin = 'auto';
      canvas.style.display = 'block';
      applyCanvasFitMode(fitMode.value);
    }
    setTimeout(() => {
      updateSidebarPosition();
    }, 150);
  } else {
    // Restore normal styles when exiting fullscreen
    if (canvas) {
      canvas.style.width = '';
      canvas.style.height = '';
      canvas.style.maxWidth = '';
      canvas.style.maxHeight = '';
      canvas.style.objectFit = '';
      canvas.style.borderRadius = '';
      canvas.style.boxShadow = '';
      canvas.style.border = '';
      canvas.style.margin = '';
    }
    changeStyle(); // Restore calculated normal style
    
    const sidebar = document.querySelector('.fullscreen-side-controls');
    if (sidebar) {
      sidebar.style.left = '';
      sidebar.style.right = '';
    }
  }
};

// Global keyboard shortcut ('F' for fullscreen, 'S' for screen fit mode)
const handleGlobalKeydown = (e) => {
  if (['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) return;
  if (e.key === 'f' || e.key === 'F') {
    e.preventDefault();
    toggleFullscreen();
  } else if ((e.key === 's' || e.key === 'S') && isFullscreen.value) {
    e.preventDefault();
    toggleFitMode();
  }
};

onMounted(async () => {
  loadingMessage.value = 'Initializing connection...';
  await scrcpyStart(renderRef.value);
  
  // Listen for fullscreen state changes
  document.addEventListener('fullscreenchange', handleFullscreenChange);
  
  // Listen for 'F' keyboard shortcut
  window.addEventListener('keydown', handleGlobalKeydown);
  
  // Window resize listener
  window.addEventListener('resize', () => {
    if (isFullscreen.value) {
      setTimeout(() => {
        updateSidebarPosition();
      }, 100);
    }
  });
});

onBeforeUnmount(async () => {
  console.log("Destroying scrcpy");
  try {
    window.removeEventListener('keydown', handleKeyEvent);
    window.removeEventListener('keyup', handleKeyEvent);
    window.removeEventListener('keydown', handleGlobalKeydown);
    document.removeEventListener('fullscreenchange', handleFullscreenChange);
    window.removeEventListener('resize', updateSidebarPosition);
    
    // 等待一小段时间，确保所有事件处理完成
    await new Promise(resolve => setTimeout(resolve, 50));
    
    // 调用销毁函数
    await destroyClient();
    console.log("scrcpy 资源已清理完成");
  } catch (error) {
    console.error("销毁 scrcpy 资源时出错:", error);
    // 即使出错，也确保设置为 null 以便垃圾回收
    try {
      // 强制清理资源的最后尝试
      if (renderRef.value && renderRef.value.renderContainer) {
        const container = renderRef.value.renderContainer;
        while (container.firstChild) {
          container.removeChild(container.firstChild);
        }
      }
    } catch (e) {
      console.warn("清理渲染容器时出错:", e);
    }
  }
});

// 暴露方法供父组件调用
defineExpose({
  pressKey,
  openKeyInput
});
</script>

<style lang="scss" scoped>
.scrcpy-container {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  position: relative;
}

.content-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
  flex-grow: 1;
}

.side-toolbar {
  position: absolute;
  right: 10px;
  top: 50%;
  transform: translateY(-50%);
  z-index: 80;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.sidebar-toggle-top {
  width: 28px;
  height: 28px;
  background-color: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(0, 0, 0, 0.1);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  margin-bottom: 8px;
  transition: all 0.3s ease;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
  
  &:hover {
    background-color: #f0f8ff;
    border-color: #1890ff;
    box-shadow: 0 3px 8px rgba(0, 0, 0, 0.15);
    transform: translateY(-1px);
    
    :deep(.el-icon) {
      color: #1890ff !important;
    }
  }
  
  :deep(.el-icon) {
    color: #666;
    transition: color 0.3s ease;
  }
}

.sidebar-expand-button {
  position: absolute;
  right: -10px; /* 移动到容器外部右侧 */
  top: 50%;
  transform: translateY(-50%);
  z-index: 90;
  
  .expand-btn {
    width: 28px;
    height: 28px;
    background-color: rgba(255, 255, 255, 0.9);
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    cursor: pointer;
    transition: all 0.3s ease;
    box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
    
    &:hover {
      background-color: #f0f8ff;
      border-color: #1890ff;
      box-shadow: 0 3px 8px rgba(0, 0, 0, 0.15);
      transform: translateY(-1px);
      
      :deep(.el-icon) {
        color: #1890ff;
      }
    }
    
    :deep(.el-icon) {
      color: #666;
      transition: color 0.3s ease;
    }
  }
}

/* 侧边栏滑动动画 */
.sidebar-slide-enter-active,
.sidebar-slide-leave-active {
  transition: all 0.3s ease;
}

.sidebar-slide-enter-from {
  transform: translateY(-50%) translateX(100%);
  opacity: 0;
}

.sidebar-slide-leave-to {
  transform: translateY(-50%) translateX(100%);
  opacity: 0;
}

.sidebar-slide-enter-to,
.sidebar-slide-leave-from {
  transform: translateY(-50%) translateX(0);
  opacity: 1;
}

.bottom-control-container {
  width: auto;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 0;
  box-sizing: border-box;
  margin-bottom: 10px;
  position: relative;
}

.video {
  border: 3px solid #303133;
  background-color: #303133;
  cursor: url("/src/assets/img/pointer.png") 2 0, crosshair;
  border-radius: 20px;
}

.error-container {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(245, 247, 250, 0.9);
  z-index: 90;

  .error-content {
    background-color: #fff;
    border-radius: 8px;
    padding: 20px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    text-align: center;
    max-width: 80%;

    h3 {
      color: #f56c6c;
      margin-top: 0;
      margin-bottom: 16px;
    }

    p {
      margin-bottom: 20px;
      color: #606266;
    }

    .retry-button {
      background-color: #409eff;
      color: white;
      border: none;
      padding: 8px 16px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 14px;
      transition: background-color 0.3s;

      &:hover {
        background-color: #66b1ff;
      }

      &:active {
        background-color: #3a8ee6;
      }
    }
  }
}

/* Non-fullscreen styling for video container */
.content-wrapper:not(:fullscreen) :deep(.video) {
  border-radius: 20px !important;
}

/* Fullscreen mode container styling */
.content-wrapper:fullscreen,
.content-wrapper:-webkit-full-screen,
.content-wrapper:-moz-full-screen {
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  width: 100vw !important;
  height: 100vh !important;
  max-width: 100vw !important;
  max-height: 100vh !important;
  background-color: #000000 !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
}

/* Fullscreen video and canvas: edge-to-edge true fullscreen */
.content-wrapper:fullscreen :deep(.video),
.content-wrapper:fullscreen :deep(canvas),
.content-wrapper:-webkit-full-screen :deep(.video),
.content-wrapper:-webkit-full-screen :deep(canvas),
:fullscreen :deep(.video),
:fullscreen :deep(canvas) {
  width: 100% !important;
  height: 100% !important;
  max-width: 100vw !important;
  max-height: 100vh !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  border: none !important;
  margin: 0 auto !important;
  display: block !important;
  transform: none !important;
}

/* 1. Fill Mode: Stretch to eliminate top & bottom black bars */
.content-wrapper.fit-fill:fullscreen :deep(.video),
.content-wrapper.fit-fill:fullscreen :deep(canvas),
.content-wrapper.fit-fill:-webkit-full-screen :deep(.video),
.content-wrapper.fit-fill:-webkit-full-screen :deep(canvas) {
  width: 100vw !important;
  height: 100vh !important;
  max-width: 100vw !important;
  max-height: 100vh !important;
  object-fit: fill !important;
  margin: 0 auto !important;
}

/* 2. 20:9 Mode: Native phone ratio (2400x1080 = 20:9) */
.content-wrapper.fit-20-9:fullscreen :deep(.video),
.content-wrapper.fit-20-9:fullscreen :deep(canvas),
.content-wrapper.fit-20-9:-webkit-full-screen :deep(.video),
.content-wrapper.fit-20-9:-webkit-full-screen :deep(canvas) {
  width: auto !important;
  height: auto !important;
  max-width: 100vw !important;
  max-height: 100vh !important;
  object-fit: contain !important;
  margin: auto !important;
}

/* 3. 11.6" Screen Mode: 16:9 widescreen format (1366x768 / 1920x1080) */
.content-wrapper.fit-11-6:fullscreen :deep(.video),
.content-wrapper.fit-11-6:fullscreen :deep(canvas),
.content-wrapper.fit-11-6:-webkit-full-screen :deep(.video),
.content-wrapper.fit-11-6:-webkit-full-screen :deep(canvas) {
  width: 100vw !important;
  height: 100vh !important;
  aspect-ratio: 16 / 9 !important;
  object-fit: fill !important;
  margin: auto !important;
}

/* Floating bottom controls in fullscreen mode */
.fullscreen-bottom-controls {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 9999;
  width: 420px;
  background-color: rgba(30, 30, 30, 0.75);
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
  padding: 6px 12px;
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  opacity: 0.25;
  transition: opacity 0.3s cubic-bezier(0.4, 0, 0.2, 1), transform 0.3s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.3s ease;
}

.fullscreen-bottom-controls:hover {
  opacity: 1 !important;
  transform: translateX(-50%) translateY(-3px);
  box-shadow: 0 12px 36px rgba(0, 0, 0, 0.85);
}

/* Floating side controls in fullscreen mode */
.fullscreen-side-controls {
  position: fixed;
  top: 50%;
  transform: translateY(-50%);
  z-index: 9999;
  background-color: rgba(30, 30, 30, 0.75);
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.6);
  padding: 10px 6px;
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.15);
  opacity: 0.25;
  transition: opacity 0.3s cubic-bezier(0.4, 0, 0.2, 1), transform 0.3s cubic-bezier(0.4, 0, 0.2, 1), box-shadow 0.3s ease;
}

.fullscreen-side-controls:hover {
  opacity: 1 !important;
  transform: translateY(-50%) translateX(-3px);
  box-shadow: 0 12px 36px rgba(0, 0, 0, 0.85);
}
</style>
