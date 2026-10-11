<template>
  <div class="scrcpy-container">
    <div :class="['content-wrapper', `mode-${screenMode}`]" ref="fullScreenContainer">
      <RenderContainer
        ref="renderRef"
        :classes="classes"
        :container-style="containerStyle"
        @pointerdown="handlePointerDown"
        @pointermove="handlePointerMove"
        @pointerup="handlePointerUp"
        @pointercancel="handlePointerUp"
        @pointerleave="handlePointerLeave"
        @contextmenu="handleContextMenu"
        @wheel="handleWheel"
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
        />
      </div>
      <!-- Fullscreen Bottom Controls -->
      <div class="fullscreen-bottom-controls" v-if="isFullscreen && !isLoading && !hasError">
        <DeviceOperateButton
          :press-key="pressKey"
          :container-width="420"
          :is-fullscreen="isFullscreen"
          :screen-mode="screenMode"
          @toggle-fullscreen="toggleFullscreen"
          @toggle-screen-mode="toggleScreenMode"
          @paste-text="handleToolbarPaste"
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
        :screen-mode="screenMode"
        @toggle-fullscreen="toggleFullscreen"
        @toggle-screen-mode="toggleScreenMode"
        @paste-text="handleToolbarPaste"
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
import { ElMessage, ElMessageBox } from 'element-plus';

const renderRef = ref();
const isLoading = ref(true);
const loadingMessage = ref('Connecting to device...');
const loadingSubMessage = ref('Please wait a moment');
const fullScreenContainer = ref(null);
const isFullscreen = ref(false);
// Sidebar visibility state - visible by default
const isSidebarVisible = ref(true);
// Coordinate tracking
const isCoordinateTrackingActive = ref(false);
const isMouseInScreen = ref(false);
const currentMouseX = ref(0);
const currentMouseY = ref(0);
const currentAbsoluteX = ref(0);
const currentAbsoluteY = ref(0);

// Screen Mode: 'original' (like photo with black bars) or 'fill' (edge-to-edge no black bars)
const screenMode = ref(localStorage.getItem('webadb_screen_mode') || 'original');

// Destructure from useScrcpy
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
  handlePointerDown: originalHandlePointerDown,
  handlePointerMove: originalHandlePointerMove,
  handlePointerUp,
  handlePointerLeave: originalHandlePointerLeave,
  handleContextMenu: originalHandleContextMenu,
  handleWheel,
  scrcpyStart,
  destroyClient,
  connectionStatus,
  connectionError,
  client,
  rotation,
  deviceRealWidth: getDeviceRealWidth,
  deviceRealHeight: getDeviceRealHeight,
  clientPositionToDevicePosition,
  pasteTextToDevice
} = useScrcpy();

// Toggle Screen Mode: Original Ratio vs Fill Mode
const toggleScreenMode = () => {
  if (screenMode.value === 'original') {
    screenMode.value = 'fill';
    ElMessage.success({
      message: '↔️ Screen Mode: Fill Mode (Edge-to-Edge, No Black Bars)',
      duration: 2500,
      showClose: true
    });
  } else {
    screenMode.value = 'original';
    ElMessage.info({
      message: '📺 Screen Mode: Original Ratio (Native Aspect Ratio, Like Photo)',
      duration: 2500,
      showClose: true
    });
  }
  localStorage.setItem('webadb_screen_mode', screenMode.value);
  applyScreenMode();
};

const applyScreenMode = () => {
  const canvas = renderRef.value?.renderContainer?.querySelector('canvas');
  if (canvas && isFullscreen.value) {
    canvas.style.objectFit = screenMode.value === 'fill' ? 'fill' : 'contain';
  }
};

// Toolbar paste handler
const handleToolbarPaste = async () => {
  let text = '';
  try {
    if (navigator.clipboard?.readText) {
      text = await navigator.clipboard.readText();
    }
  } catch (err) {
    console.warn('Direct clipboard read failed:', err);
  }

  if (text) {
    await pasteTextToDevice(text);
    ElMessage.success({
      message: `📋 Pasted to device: "${text.length > 25 ? text.substring(0, 25) + '...' : text}"`,
      duration: 2500,
      showClose: true
    });
  } else {
    // Show prompt dialog for user to paste or type text
    ElMessageBox.prompt('Type or paste text to send to your device:', 'Send Text to Device', {
      confirmButtonText: 'Send to Device',
      cancelButtonText: 'Cancel',
      inputPlaceholder: 'Enter text here...',
      inputType: 'textarea',
      roundButton: true,
    }).then(async ({ value }) => {
      if (value) {
        await pasteTextToDevice(value);
        ElMessage.success({
          message: `✉️ Sent to device: "${value.length > 25 ? value.substring(0, 25) + '...' : value}"`,
          duration: 2500,
          showClose: true
        });
      }
    }).catch(() => {});
  }
};

// Pointer down handler to blur active elements when clicking screen
const handlePointerDown = async (event) => {
  if (document.activeElement && document.activeElement !== document.body) {
    document.activeElement.blur?.();
  }
  await originalHandlePointerDown(event);
};

// Pointer move with coordinate tracking
const handlePointerMove = async (event) => {
  currentMouseX.value = event.clientX;
  currentMouseY.value = event.clientY;

  if (isCoordinateTrackingActive.value) {
    const container = renderRef.value?.renderContainer;
    if (container) {
      const rect = container.getBoundingClientRect();
      const relX = event.clientX - rect.left;
      const relY = event.clientY - rect.top;

      const isInBounds = relX >= 0 && relX <= rect.width && relY >= 0 && relY <= rect.height;
      isMouseInScreen.value = isInBounds;

      if (isInBounds) {
        let pointerViewX = relX / rect.width;
        let pointerViewY = relY / rect.height;

        let adjustedX = pointerViewX;
        let adjustedY = pointerViewY;

        if (rotation === 1) {
          [adjustedX, adjustedY] = [adjustedY, 1 - adjustedX];
        } else if (rotation === 2) {
          adjustedX = 1 - adjustedX;
          adjustedY = 1 - adjustedY;
        } else if (rotation === 3) {
          [adjustedX, adjustedY] = [1 - adjustedY, adjustedX];
        }

        const deviceWidth = getDeviceRealWidth();
        const deviceHeight = getDeviceRealHeight();
        currentAbsoluteX.value = Math.round(adjustedX * deviceWidth);
        currentAbsoluteY.value = Math.round(adjustedY * deviceHeight);
      }
    }
  }

  await originalHandlePointerMove(event);
};

const handlePointerLeave = async (event) => {
  isMouseInScreen.value = false;
  await originalHandlePointerLeave(event);
};

const handleContextMenu = async (event) => {
  if (isCoordinateTrackingActive.value) {
    copyCoordinatesToClipboard();
    event.preventDefault();
    return;
  }
  await originalHandleContextMenu(event);
};

const toggleFocus = () => {
  isCoordinateTrackingActive.value = !isCoordinateTrackingActive.value;
  if (!isCoordinateTrackingActive.value) {
    isMouseInScreen.value = false;
  }
  ElMessage({
    message: isCoordinateTrackingActive.value 
      ? '🎯 Coordinate tracking enabled. Right click to copy coordinates.' 
      : 'Coordinate tracking disabled',
    type: isCoordinateTrackingActive.value ? 'success' : 'info',
    duration: 3000
  });
};

const copyCoordinatesToClipboard = async () => {
  try {
    const deviceWidth = getDeviceRealWidth();
    const deviceHeight = getDeviceRealHeight();
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
  }
};

const calcWidthAndHeight = computed(() => {
  const [calcWidth, calcHeight] = swapWidthHeight(width.value, height.value)
  return [calcWidth, calcHeight]
});

const pressKey = (event, type) => {
  console.log('Event:', event);
  console.log('Type:', type, AndroidKeyCode[type]);
  handleKeyEvent(event, AndroidKeyCode[type]);
};

const toggleSidebar = () => {
  isSidebarVisible.value = !isSidebarVisible.value;
  console.log('Toggle sidebar:', isSidebarVisible.value);
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

// Update sidebar position in fullscreen mode
const updateSidebarPosition = () => {
  const canvas = renderRef.value?.renderContainer?.querySelector('canvas');
  const sidebar = document.querySelector('.fullscreen-side-controls');
  
  if (canvas && sidebar) {
    const canvasRect = canvas.getBoundingClientRect();
    const rightPosition = canvasRect.right + 16;
    
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
  if (client) {
    const renderer = document.querySelector('.video');
    if (renderer) {
      const currentTransform = renderer.style.transform || '';
      if (currentTransform.includes('rotate(90deg)')) {
        renderer.style.transform = currentTransform.replace('rotate(90deg)', 'rotate(180deg)');
      } else if (currentTransform.includes('rotate(180deg)')) {
        renderer.style.transform = currentTransform.replace('rotate(180deg)', 'rotate(270deg)');
      } else if (currentTransform.includes('rotate(270deg)')) {
        renderer.style.transform = currentTransform.replace('rotate(270deg)', '');
      } else {
        renderer.style.transform = (currentTransform + ' rotate(90deg)').trim();
      }
    }
  }
};

const toggleNotifications = async () => {
  if (client && client.controller) {
    try {
      const deviceWidth = getDeviceRealWidth();
      const deviceHeight = getDeviceRealHeight();

      await client.controller.injectSwipe({
        pointerId: ScrcpyPointerId.MOUSE,
        action: AndroidMotionEventAction.DOWN,
        buttons: AndroidMotionEventButton.Primary,
        position: { x: deviceWidth / 2, y: 10 },
        pressure: 1,
      });
      
      await new Promise(resolve => setTimeout(resolve, 10));
      
      await client.controller.injectSwipe({
        pointerId: ScrcpyPointerId.MOUSE,
        action: AndroidMotionEventAction.MOVE,
        buttons: AndroidMotionEventButton.Primary,
        position: { x: deviceWidth / 2, y: deviceHeight / 4 },
        pressure: 1,
      });
      
      await new Promise(resolve => setTimeout(resolve, 10));
      
      await client.controller.injectSwipe({
        pointerId: ScrcpyPointerId.MOUSE,
        action: AndroidMotionEventAction.UP,
        buttons: AndroidMotionEventButton.Primary,
        position: { x: deviceWidth / 2, y: deviceHeight / 4 },
        pressure: 0,
      });
    } catch (error) {
      console.error('Notifications action error:', error);
    }
  }
};

const hasError = computed(() => connectionStatus.value === 'error');

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

watch([windowWidth, windowHeight], ([newWidth, newHeight]) => {
  if (width.value !== 0 || height.value !== 0) {
    changeStyle();
  }
});

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

watch(connectionStatus, (newStatus) => {
  switch (newStatus) {
    case 'idle':
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
      canvas.style.width = '100%';
      canvas.style.height = '100%';
      canvas.style.maxWidth = '100vw';
      canvas.style.maxHeight = '100vh';
      canvas.style.objectFit = screenMode.value === 'fill' ? 'fill' : 'contain';
      canvas.style.borderRadius = '0px';
      canvas.style.boxShadow = 'none';
      canvas.style.border = 'none';
      canvas.style.margin = '0 auto';
      canvas.style.display = 'block';
    }
    setTimeout(() => {
      updateSidebarPosition();
    }, 150);
  } else {
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
    changeStyle();
    
    const sidebar = document.querySelector('.fullscreen-side-controls');
    if (sidebar) {
      sidebar.style.left = '';
      sidebar.style.right = '';
    }
  }
};

onMounted(async () => {
  loadingMessage.value = 'Initializing connection...';
  await scrcpyStart(renderRef.value);
  
  // Enable keyboard and clipboard listeners
  openKeyInput('open');

  // Listen for fullscreen state changes
  document.addEventListener('fullscreenchange', handleFullscreenChange);
  
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
    openKeyInput('close');
    document.removeEventListener('fullscreenchange', handleFullscreenChange);
    window.removeEventListener('resize', updateSidebarPosition);
    
    await new Promise(resolve => setTimeout(resolve, 50));
    await destroyClient();
    console.log("scrcpy resources cleaned up");
  } catch (error) {
    console.error("Error destroying scrcpy:", error);
  }
});

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
  right: -10px;
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

:deep(.video) {
  border-radius: 20px !important;
}

/* Fullscreen mode base container */
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

/* Fullscreen video and canvas common */
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

/* Mode 1: Original Ratio Mode (like photo: media_1791709071423.jpg) */
.content-wrapper.mode-original:fullscreen :deep(.video),
.content-wrapper.mode-original:fullscreen :deep(canvas),
.content-wrapper.mode-original:-webkit-full-screen :deep(.video),
.content-wrapper.mode-original:-webkit-full-screen :deep(canvas) {
  object-fit: contain !important;
  background-color: #000000 !important;
}

/* Mode 2: Fill Mode (stretches to fill entire monitor edge-to-edge without black bars) */
.content-wrapper.mode-fill:fullscreen :deep(.video),
.content-wrapper.mode-fill:fullscreen :deep(canvas),
.content-wrapper.mode-fill:-webkit-full-screen :deep(.video),
.content-wrapper.mode-fill:-webkit-full-screen :deep(canvas) {
  object-fit: fill !important;
}

.fullscreen-bottom-controls {
  position: fixed;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  z-index: 9999;
  width: 420px;
  background-color: rgba(40, 40, 40, 0.95);
  border-radius: 16px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);
  padding: 8px 10px;
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border: 1px solid rgba(80, 80, 80, 0.5);
  opacity: 0.35;
  transition: opacity 0.3s ease, transform 0.3s ease, box-shadow 0.3s ease;
}

.fullscreen-bottom-controls:hover {
  opacity: 1 !important;
  transform: translateX(-50%) translateY(-3px);
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.7);
}

.fullscreen-side-controls {
  position: fixed;
  top: 50%;
  transform: translateY(-50%);
  z-index: 9999;
  background-color: rgba(40, 40, 40, 0.95);
  border-radius: 16px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);
  padding: 10px 5px;
  backdrop-filter: blur(8px);
  -webkit-backdrop-filter: blur(8px);
  border: 1px solid rgba(80, 80, 80, 0.5);
  opacity: 0.35;
  transition: opacity 0.3s ease, transform 0.3s ease, box-shadow 0.3s ease;
}

.fullscreen-side-controls:hover {
  opacity: 1 !important;
  transform: translateY(-50%) translateX(-3px);
  box-shadow: 0 6px 24px rgba(0, 0, 0, 0.7);
}
</style>
