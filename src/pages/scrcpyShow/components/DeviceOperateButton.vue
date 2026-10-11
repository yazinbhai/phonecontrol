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
      <el-tooltip effect="dark" :content="fitModeTooltip" placement="top" v-if="isFullscreen">
        <el-button @click="handleToggleFitMode" class="fit-mode-btn">
          <el-icon :size="16"><ScaleToOriginal /></el-icon>
        </el-button>
      </el-tooltip>
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

const emit = defineEmits(['toggle-fullscreen', 'toggle-fit-mode']);

const fitModeTooltip = computed(() => {
  if (props.fitMode === 'fill') {
    return 'Aspect Ratio: Stretch to Fill (No black bars) - Click to toggle (S)';
  } else if (props.fitMode === 'cover') {
    return 'Aspect Ratio: Zoom to Fill (Proportional) - Click to toggle (S)';
  } else {
    return 'Aspect Ratio: Original (Black bars) - Click to toggle (S)';
  }
});

const controlBarStyle = computed(() => {
  // If container width is available, set to container width
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

const handleToggleFitMode = () => {
  emit('toggle-fit-mode');
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
  padding: 0 50px;
}

.el-button {
  border: none;
  margin: 0;
  padding: 8px;
}

/* 全屏模式下的样式 */
.fullscreen-mode {
  background-color: transparent;
  box-shadow: none;
}

.fullscreen-mode .button-container {
  padding: 0 20px;
  display: flex;
  justify-content: space-around;
}

.fullscreen-mode .el-button {
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

.fullscreen-mode .el-button:hover {
  background-color: rgba(80, 80, 80, 1);
  transform: scale(1.1);
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.5);
}

.fullscreen-mode :deep(.el-icon) {
  color: rgba(255, 255, 255, 0.95);
  font-size: 20px;
  filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.5));
}
</style>
