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

      <!-- Screen Mode: Original Ratio (like photo) vs Fill Mode -->
      <el-tooltip effect="dark" :content="screenModeTooltip" placement="top">
        <el-button @click="handleToggleScreenMode" class="mode-btn">
          <el-icon :size="16">
            <ScaleToOriginal v-if="screenMode === 'original'" />
            <Crop v-else />
          </el-icon>
        </el-button>
      </el-tooltip>

      <!-- Fullscreen Toggle -->
      <el-tooltip effect="dark" :content="isFullscreen ? 'Exit Fullscreen' : 'Fullscreen'" placement="top">
        <el-button @click="handleToggleFullscreen" class="fullscreen-btn">
          <el-icon :size="16"><FullScreen /></el-icon>
        </el-button>
      </el-tooltip>
    </div>
  </div>
</template>

<script setup>
import { 
  Menu, CopyDocument, House, Back, FullScreen, ScaleToOriginal, Crop
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
  screenMode: {
    type: String,
    default: 'original' // 'original' (like photo with black bars) or 'fill' (no black bars)
  }
});

const emit = defineEmits(['toggle-fullscreen', 'toggle-screen-mode']);

const screenModeTooltip = computed(() => {
  if (props.screenMode === 'original') {
    return '📺 Current: Original Ratio (Like Photo with black bars) — Click for Fill Mode';
  }
  return '↔️ Current: Fill Mode (Edge-to-Edge, No black bars) — Click for Original Ratio';
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

const handleToggleScreenMode = () => {
  emit('toggle-screen-mode');
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
