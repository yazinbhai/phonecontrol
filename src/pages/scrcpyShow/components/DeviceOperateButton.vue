<template>
  <div class="device-control-bar" :style="controlBarStyle" :class="{ 'fullscreen-mode': isFullscreen }">
    <div class="button-container">
      <el-tooltip effect="dark" content="Back" placement="top">
        <el-button @click="handlePress('AndroidBack')">
          <el-icon :size="16"><Back /></el-icon>
        </el-button>
      </el-tooltip>
      <el-tooltip effect="dark" content="Home" placement="top">
        <el-button @click="handlePress('AndroidHome')">
          <el-icon :size="16"><House /></el-icon>
        </el-button>
      </el-tooltip>
      <el-tooltip effect="dark" content="Recent Apps" placement="top">
        <el-button @click="handlePress('AndroidAppSwitch')">
          <el-icon :size="16"><CopyDocument /></el-icon>
        </el-button>
      </el-tooltip>
      <el-tooltip effect="dark" content="Menu" placement="top">
        <el-button @click="handlePress('ContextMenu')">
          <el-icon :size="16"><Menu /></el-icon>
        </el-button>
      </el-tooltip>
      <el-tooltip effect="dark" :content="isFullscreen ? 'Exit Fullscreen (F)' : 'Fullscreen (F)'" placement="top">
        <el-button @click="handleToggleFullscreen" class="fullscreen-btn">
          <el-icon :size="16"><FullScreen /></el-icon>
        </el-button>
      </el-tooltip>
      <el-dropdown trigger="click" @command="handleCommand">
        <el-tooltip effect="dark" :content="fitModeTooltip" placement="top">
          <el-button class="fit-mode-btn">
            <el-icon :size="16"><ScaleToOriginal /></el-icon>
          </el-button>
        </el-tooltip>
        <template #dropdown>
          <el-dropdown-menu class="screen-mode-menu">
            <el-dropdown-item command="fill" :class="{ 'is-selected': fitMode === 'fill' }">
              <span class="menu-item-row">
                <span class="mode-icon">🖥️</span>
                <span><strong>Fill Mode</strong> (Stretch to Fill)</span>
              </span>
            </el-dropdown-item>
            <el-dropdown-item command="20:9" :class="{ 'is-selected': fitMode === '20:9' }">
              <span class="menu-item-row">
                <span class="mode-icon">📱</span>
                <span><strong>20:9 Mode</strong> (Native Phone Ratio)</span>
              </span>
            </el-dropdown-item>
            <el-dropdown-item command="11.6" :class="{ 'is-selected': fitMode === '11.6' }">
              <span class="menu-item-row">
                <span class="mode-icon">💻</span>
                <span><strong>11.6" Screen</strong> (16:9 Widescreen)</span>
              </span>
            </el-dropdown-item>
            <el-dropdown-item divided command="adb-11.6">
              <span class="menu-item-row adb-action">
                <span class="mode-icon">⚡</span>
                <span>Adapt Phone to 11.6" (ADB 16:9)</span>
              </span>
            </el-dropdown-item>
            <el-dropdown-item command="adb-reset">
              <span class="menu-item-row adb-action">
                <span class="mode-icon">↺</span>
                <span>Reset Phone to 20:9 (ADB Native)</span>
              </span>
            </el-dropdown-item>
          </el-dropdown-menu>
        </template>
      </el-dropdown>
    </div>
  </div>
</template>

<script setup>
import { 
  Menu, CopyDocument, House, Back, FullScreen, ScaleToOriginal
} from "@element-plus/icons-vue";
import { computed } from 'vue';

const props = defineProps({
  pressKey: Function,
  containerWidth: {
    type: Number,
    default: 0
  },
  isFullscreen: {
    type: Boolean,
    default: false
  },
  fitMode: {
    type: String,
    default: 'fill'
  }
});

const emit = defineEmits(['toggle-fullscreen', 'set-fit-mode', 'toggle-fit-mode', 'apply-adb-mode']);

const fitModeTooltip = computed(() => {
  if (props.fitMode === 'fill') {
    return 'Display: Fill Mode (Stretch) - Click to change (S)';
  } else if (props.fitMode === '20:9') {
    return 'Display: 20:9 Native Ratio - Click to change (S)';
  } else if (props.fitMode === '11.6') {
    return 'Display: 11.6" Screen (16:9) - Click to change (S)';
  }
  return 'Display: Aspect Ratio Options (S)';
});

const controlBarStyle = computed(() => {
  if (props.containerWidth && props.containerWidth > 0) {
    return {
      width: `${props.containerWidth}px`,
      maxWidth: '100%'
    };
  }
  return {
    width: '100%',
    maxWidth: '100%'
  };
});

const handlePress = (key) => {
  if (props.pressKey) {
    props.pressKey(null, key);
  }
};

const handleToggleFullscreen = () => {
  emit('toggle-fullscreen');
};

const handleCommand = (command) => {
  if (command === 'adb-11.6') {
    emit('apply-adb-mode', '11.6');
  } else if (command === 'adb-reset') {
    emit('apply-adb-mode', 'reset');
  } else {
    emit('set-fit-mode', command);
  }
};
</script>

<style scoped>
.device-control-bar {
  margin-top: 10px;
  padding: 8px 0;
  background-color: #ffffff;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0,0,0,0.05);
  display: flex;
  justify-content: center;
  align-items: center;
  box-sizing: border-box;
}

.button-container {
  display: flex;
  justify-content: space-between;
  width: 100%;
  padding: 0 30px;
}

.el-button {
  border: none;
  margin: 0;
  padding: 8px;
}

.menu-item-row {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13px;
}

.mode-icon {
  font-size: 16px;
}

.adb-action {
  color: #409eff;
}

/* 全屏模式下的样式 */
.fullscreen-mode {
  background-color: transparent;
  box-shadow: none;
}

.fullscreen-mode .button-container {
  padding: 0 15px;
  display: flex;
  justify-content: space-around;
}

.fullscreen-mode :deep(.el-button) {
  background-color: rgba(60, 60, 60, 0.9);
  border-radius: 50%;
  width: 44px;
  height: 44px;
  display: flex;
  justify-content: center;
  align-items: center;
  transition: all 0.3s ease;
  color: white;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
  border: 1px solid rgba(100, 100, 100, 0.5);
}

.fullscreen-mode :deep(.el-button:hover) {
  background-color: rgba(80, 80, 80, 1);
  transform: scale(1.1);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
}

.fullscreen-mode :deep(.el-icon) {
  color: rgba(255, 255, 255, 0.95);
  font-size: 20px;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.5));
}

:deep(.el-dropdown-menu__item.is-selected) {
  background-color: #ecf5ff;
  color: #409eff;
  font-weight: 600;
}
</style>
