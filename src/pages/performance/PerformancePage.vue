<template>
  <div class="performance-page">
    <div class="container">
      <!-- Control Panel -->
      <el-card class="mb-4 control-panel-card">
        <div class="panel-container">
          <!-- Left: Settings -->
          <div class="left-panel">
            <div class="settings-group">
              <div class="setting-item">
                <div class="label"><el-icon><Menu /></el-icon> Monitored App</div>
                <el-select 
                  v-model="selectedPackage"
                  placeholder="Select an app to monitor"
                  :disabled="isMonitoring"
                  filterable
                  class="full-width"
                  @change="onAppSelected"
                >
                  <template #prefix>
                    <el-icon><Search /></el-icon>
                  </template>
                  <el-option
                    v-for="app in installedApps"
                    :key="app.packageName"
                    :label="app.appName"
                    :value="app.packageName"
                  >
                    <span>{{ app.appName }}</span>
                    <span class="option-pkg">{{ app.packageName }}</span>
                  </el-option>
                </el-select>
              </div>
              
              <!-- PID Selection -->
              <div class="setting-item" v-if="processList.length > 0">
                <div class="label"><el-icon><Phone /></el-icon> Select Process</div>
                <el-select 
                  v-model="selectedPid"
                  placeholder="Select application process"
                  :disabled="isMonitoring"
                  class="full-width"
                >
                  <el-option
                    v-for="process in processList"
                    :key="process.pid"
                    :label="`PID: ${process.pid} | ${process.name}`"
                    :value="process.pid"
                  />
                </el-select>
              </div>
              
              <div class="setting-item">
                <div class="label"><el-icon><Timer /></el-icon> Interval</div>
                <el-select 
                  v-model="collectionInterval"
                  :disabled="isMonitoring"
                  style="width: 150px"
                >
                  <el-option label="1 s" value="1000" />
                  <el-option label="2 s" value="2000" />
                  <el-option label="5 s" value="5000" />
                  <el-option label="10 s" value="10000" />
                </el-select>
                <el-button
                  type="warning"
                  @click="refreshAppList"
                  :disabled="isLoading || isMonitoring"
                  :loading="isLoading"
                  :icon="Timer"
                >Refresh Apps
                </el-button>
                <el-button
                  type="success"
                  @click="getCurrentApp"
                  :disabled="isLoading"
                  :loading="isGettingCurrentApp"
                  :icon="Search"
                >Get Current App
                </el-button>
              </div>
              <div class="setting-item">
                <div class="label"><el-icon><DataAnalysis /></el-icon> Data Cap</div>
                <el-select 
                  v-model="localMaxDataPoints"
                  :disabled="isMonitoring"
                  style="width: 150px"
                  @change="updateMaxDataPoints"
                >
                  <el-option label="300 pts (Default)" :value="300" />
                  <el-option label="500 pts" :value="500" />
                  <el-option label="1000 pts" :value="1000" />
                  <el-option label="2000 pts" :value="2000" />
                  <el-option label="5000 pts" :value="5000" />
                  <el-option label="Unlimited" :value="0" />
                </el-select>
                <el-tooltip content="Higher limits consume more memory. Unlimited may cause high memory usage over time." placement="top">
                  <el-icon class="info-icon"><InfoFilled /></el-icon>
                </el-tooltip>
              </div>
            </div>
          </div>

          <!-- Right: Status and Actions -->
          <div class="right-panel">
            <!-- Status Display -->
            <div class="status-display">
              <template v-if="isMonitoring">
                <div class="monitoring-status">
                  <div class="app-name">
                    <el-icon><Loading class="is-loading" /></el-icon>
                    <span>{{ currentAppName }}</span>
                  </div>
                  <div class="duration">
                    Duration: {{ monitoringDuration }}
                  </div>
                </div>
              </template>
              <template v-else>
                <div class="idle-status">
                  <el-icon><InfoFilled /></el-icon>
                  <span>Idle. Please select an app to start monitoring</span>
                </div>
              </template>
            </div>
            
            <!-- Actions -->
            <div class="action-buttons-container">
              <div class="action-buttons">
                <el-button 
                  v-if="!isMonitoring" 
                  type="primary" 
                  @click="startMonitoring"
                  :disabled="!selectedPackage || isLoading"
                  class="action-btn"
                >
                  <el-icon class="mx-2"><VideoPlay /></el-icon>
                  Start Monitor
                </el-button>
                <el-button 
                  v-else 
                  type="danger" 
                  @click="stopMonitoring"
                  class="action-btn"
                >
                  <el-icon class="mx-2"><VideoPause /></el-icon>
                  Stop Monitor
                </el-button>
                <el-button 
                  type="success"
                  @click="exportData"
                  :disabled="performanceStore.timeStamps.length === 0 || isMonitoring"
                  class="action-btn"
                >
                  <el-icon class="mx-2"><Download /></el-icon>
                  Export Report
                </el-button>
              </div>
            </div>
          </div>
        </div>
        
        <!-- Real-time Stats Display -->
        <el-divider v-if="isMonitoring" />
        <el-row :gutter="20" v-if="isMonitoring" class="live-stats">
          <el-col :span="6">
            <el-statistic title="CPU Usage" :value="latestCpu">
              <template #suffix>%</template>
            </el-statistic>
          </el-col>
          <el-col :span="6">
            <el-statistic title="Memory Usage" :value="latestMemory">
              <template #suffix>MB</template>
            </el-statistic>
          </el-col>
          <el-col :span="6">
            <el-statistic title="Real-time FPS" :value="latestFps">
               <template #suffix>FPS</template>
            </el-statistic>
          </el-col>
          <el-col :span="6">
            <el-statistic title="Battery Temp" :value="latestTemp">
              <template #suffix>°C</template>
            </el-statistic>
          </el-col>
          <!-- Foreground App Info -->
          <el-col :span="24" class="mt-3">
            <el-card class="foreground-app-card" shadow="never">
              <template #header>
                <div class="card-header">
                  <span class="title">Current Foreground App</span>
                  <el-tag
                    :type="currentForegroundApp.packageName ? 'success' : 'info'"
                    size="small"
                  >
                    {{ currentForegroundApp.packageName ? 'Detected' : 'None' }}
                  </el-tag>
                </div>
              </template>

              <div v-if="currentForegroundApp.packageName" class="app-details">
                <div class="detail-row">
                  <span class="label">App Name:</span>
                  <span class="value">{{ currentForegroundApp.appName || 'Unknown' }}</span>
                </div>
                <div class="detail-row">
                  <span class="label">App Type:</span>
                  <el-tag
                    size="small"
                    :type="currentForegroundApp.isSystemApp ? 'warning' : 'success'"
                  >
                    {{ currentForegroundApp.isSystemApp ? 'System App' : 'Third-Party App' }}
                  </el-tag>
                </div>
                <div class="detail-row">
                  <span class="label">Package:</span>
                  <span class="value">{{ currentForegroundApp.packageName }}</span>
                </div>
                <div class="detail-row">
                  <span class="label">Process ID:</span>
                  <span class="value">{{ currentForegroundApp.pid || 'Unknown' }}</span>
                </div>
              </div>

              <div v-else class="no-app">
                <span class="no-app-text">No foreground app detected</span>
              </div>
            </el-card>
          </el-col>

          <el-col :span="24" class="data-info mt-2">
            <div class="data-point-info">
              <el-icon><InfoFilled /></el-icon>
              <span>
                Collected {{ performanceStore.timeStamps.length }} data points
                {{ performanceStore.maxDataPoints > 0 ? `(Max ${performanceStore.maxDataPoints})` : '(Unlimited)' }},
                charts display the last 60 points; export includes all data.
              </span>
            </div>
          </el-col>
        </el-row>
      </el-card>
      
      <!-- Charts Section -->
      <el-row :gutter="20">
        <!-- CPU Usage Chart -->
        <el-col :xs="24" :sm="24" :md="12" class="mb-4">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <h5 class="card-title">CPU Usage</h5>
              </div>
            </template>
            <div class="chart-placeholder">
              <div v-if="!isMonitoring" class="chart-empty-state">
                <div class="empty-chart-container">
                  <el-icon class="empty-icon"><Cpu /></el-icon>
                  <div class="empty-text">CPU usage chart will appear once monitoring starts</div>
                </div>
              </div>
              <CpuChart v-else />
            </div>
          </el-card>
        </el-col>
        
        <!-- Memory Usage Chart -->
        <el-col :xs="24" :sm="24" :md="12" class="mb-4">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <h5 class="card-title">Memory Usage</h5>
              </div>
            </template>
            <div class="chart-placeholder">
              <div v-if="!isMonitoring" class="chart-empty-state">
                <div class="empty-chart-container">
                  <el-icon class="empty-icon"><Histogram /></el-icon>
                  <div class="empty-text">Memory usage chart will appear once monitoring starts</div>
                </div>
              </div>
              <MemoryChart v-else />
            </div>
          </el-card>
        </el-col>
        
        <!-- FPS Chart -->
        <el-col :xs="24" :sm="24" :md="12" class="mb-4">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <h5 class="card-title">FPS</h5>
              </div>
            </template>
            <div class="chart-placeholder">
              <div v-if="!isMonitoring" class="chart-empty-state">
                <div class="empty-chart-container">
                  <el-icon class="empty-icon"><DataAnalysis /></el-icon>
                  <div class="empty-text">FPS chart will appear once monitoring starts</div>
                </div>
              </div>
              <FpsChart v-else />
            </div>
          </el-card>
        </el-col>
        
        <!-- Network Traffic Chart -->
        <el-col :xs="24" :sm="24" :md="12" class="mb-4">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <h5 class="card-title">Network Traffic</h5>
              </div>
            </template>
            <div class="chart-placeholder">
              <div v-if="!isMonitoring" class="chart-empty-state">
                <div class="empty-chart-container">
                  <el-icon class="empty-icon"><Connection /></el-icon>
                  <div class="empty-text">Network traffic chart will appear once monitoring starts</div>
                </div>
              </div>
              <NetworkChart v-else />
            </div>
          </el-card>
        </el-col>
        
        <!-- Battery Level Chart -->
        <el-col :xs="24" :sm="24" :md="12" class="mb-4">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <h5 class="card-title">Battery Level</h5>
              </div>
            </template>
            <div class="chart-placeholder">
              <div v-if="!isMonitoring" class="chart-empty-state">
                <div class="empty-chart-container">
                  <el-icon class="empty-icon"><Odometer /></el-icon>
                  <div class="empty-text">Battery level chart will appear once monitoring starts</div>
                </div>
              </div>
              <BatteryChart v-else />
            </div>
          </el-card>
        </el-col>
        
        <!-- Battery Temperature Chart -->
        <el-col :xs="24" :sm="24" :md="12" class="mb-4">
          <el-card class="chart-card">
            <template #header>
              <div class="card-header">
                <h5 class="card-title">Battery Temperature</h5>
              </div>
            </template>
            <div class="chart-placeholder">
              <div v-if="!isMonitoring" class="chart-empty-state">
                <div class="empty-chart-container">
                  <el-icon class="empty-icon"><Odometer /></el-icon>
                  <div class="empty-text">Battery temperature chart will appear once monitoring starts</div>
                </div>
              </div>
              <TemperatureChart v-else />
            </div>
          </el-card>
        </el-col>
      </el-row>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { usePerformanceStore } from '../../stores/performance';
import { useDeviceStore } from '../../stores/device';
import { getInstalledApps, getProcessList } from '../../utils/adbManager';
import {
  initMonitor,
  startMonitoring as startMonitoringAPI,
  stopMonitoring as stopMonitoringAPI,
  setMonitoringInterval
} from '../../utils/performance/performanceMonitor';
import { collectForegroundApp } from '../../utils/performance/collectors/foregroundAppCollector';
import { ElMessage, ElMessageBox } from 'element-plus';
import { Cpu, Histogram, DataAnalysis, Connection, Odometer, VideoPlay, VideoPause, Download, Menu, Phone, Search, Timer, Clock, InfoFilled, Loading, Refresh } from '@element-plus/icons-vue';

// 导入图表组件
import CpuChart from './components/CpuChart.vue';
import MemoryChart from './components/MemoryChart.vue';
import FpsChart from './components/FpsChart.vue';
import NetworkChart from './components/NetworkChart.vue';
import BatteryChart from './components/BatteryChart.vue';
import TemperatureChart from './components/TemperatureChart.vue';

// 状态
const installedApps = ref([]);
const selectedPackage = ref('');
const isLoading = ref(false);
const collectionInterval = ref(1000);
const monitoringStartTime = ref(null);
const monitoringDuration = ref('');
let durationTimer = null;
const localMaxDataPoints = ref(300); // 本地状态用于绑定选择器
const processList = ref([]); // 存储进程列表
const selectedPid = ref(''); // 选中的进程ID
const isGettingCurrentApp = ref(false); // 获取当前应用的加载状态

// Store
const performanceStore = usePerformanceStore();
const deviceStore = useDeviceStore();

// 计算属性
const isMonitoring = computed(() => performanceStore.isMonitoring);
const currentAppName = computed(() => {
  if (!performanceStore.currentPackageName) return '';
  
  const app = installedApps.value.find(
    app => app.packageName === performanceStore.currentPackageName
  );
  return app ? app.appName : performanceStore.currentPackageName;
});

const latestCpu = computed(() => {
  const history = performanceStore.cpuAppHistory;
  return history.length > 0 ? history[history.length - 1] : 0;
});

const latestMemory = computed(() => {
  const history = performanceStore.memoryTotalHistory;
  return history.length > 0 ? history[history.length - 1] : 0;
});

const latestFps = computed(() => {
  const history = performanceStore.fpsHistory;
  return history.length > 0 ? history[history.length - 1] : 0;
});

const latestTemp = computed(() => {
  const history = performanceStore.batteryTemperatureHistory;
  return history.length > 0 ? history[history.length - 1] : 0;
});

// 当前前台应用信息
const currentForegroundApp = computed(() => performanceStore.currentForegroundAppInfo);

// 方法
const refreshAppList = async () => {
  isLoading.value = true;
  try {
    installedApps.value = await getInstalledApps(false);
  } catch (error) {
    console.error('获取应用列表失败:', error);
  } finally {
    isLoading.value = false;
  }
};

// Get current foreground app
const getCurrentApp = async () => {
  isGettingCurrentApp.value = true;
  try {
    const foregroundApp = await collectForegroundApp();

    if (foregroundApp && foregroundApp.packageName) {
      // Check if system app
      if (foregroundApp.isSystemApp) {
        // System app prompt
        ElMessageBox.confirm(
          `Detected that the current foreground app is a built-in system app: ${foregroundApp.appName || foregroundApp.packageName}.\n\nPerformance metrics for system apps may be limited or less accurate.\n\nDo you still wish to monitor this app?`,
          'System App Notice',
          {
            confirmButtonText: 'Continue',
            cancelButtonText: 'Cancel',
            type: 'warning',
            center: true
          }
        ).then(async () => {
          // Continue monitoring
          await selectAndMonitorApp(foregroundApp);
        }).catch(() => {
          // User cancelled
          ElMessage.info({
            message: 'Cancelled monitoring system app',
            duration: 2000
          });
        });
      } else {
        // Third-party app, select directly
        await selectAndMonitorApp(foregroundApp);
      }
    } else {
      ElMessage.warning({
        message: 'No foreground app detected. Please make sure an app is running on the device.',
        duration: 3000
      });
    }
  } catch (error) {
    console.error('Failed to get current app:', error);
    ElMessage.error({
      message: 'Failed to get current app. Please check device connection.',
      duration: 3000
    });
  } finally {
    isGettingCurrentApp.value = false;
  }
};

// Select and prepare monitoring app
const selectAndMonitorApp = async (foregroundApp) => {
  try {
    // Check if app is in installed apps list
    const existingApp = installedApps.value.find(app => app.packageName === foregroundApp.packageName);

    if (existingApp) {
      selectedPackage.value = foregroundApp.packageName;
      await onAppSelected(foregroundApp.packageName);
    } else {
      const newApp = {
        packageName: foregroundApp.packageName,
        appName: foregroundApp.appName || foregroundApp.packageName
      };
      installedApps.value.unshift(newApp);
      selectedPackage.value = foregroundApp.packageName;
      await onAppSelected(foregroundApp.packageName);
    }

    const appType = foregroundApp.isSystemApp ? 'system app' : 'third-party app';
    const addedText = existingApp ? '' : ' (added to app list)';

    ElMessage.success({
      message: `Selected foreground ${appType}: ${foregroundApp.appName || foregroundApp.packageName}${addedText}`,
      duration: 3000
    });
  } catch (error) {
    console.error('Failed to select app:', error);
    ElMessage.error({
      message: 'Failed to select app, please try again',
      duration: 3000
    });
  }
};

const onAppSelected = async (packageName) => {
  if (!packageName) {
    processList.value = [];
    selectedPid.value = '';
    return;
  }
  
  isLoading.value = true;
  try {
    const processes = await getProcessList(packageName);
    processList.value = processes;
    
    if (processes.length === 1) {
      selectedPid.value = processes[0].pid;
    } else if (processes.length > 1) {
      selectedPid.value = processes[0].pid;
    } else {
      selectedPid.value = '';
      ElMessage.warning(`No process found for app ${packageName}`);
    }
  } catch (error) {
    console.error('Failed to get process list:', error);
    ElMessage.error('Failed to get process list');
    processList.value = [];
    selectedPid.value = '';
  } finally {
    isLoading.value = false;
  }
};

const startMonitoring = async () => {
  if (!selectedPackage.value) {
    ElMessage.warning('Please select an app to monitor first');
    return;
  }

  if (!selectedPid.value && processList.value.length > 0) {
    ElMessage.warning('Please select a process to monitor');
    return;
  }

  isLoading.value = true;
  try {
    const success = await startMonitoringAPI(selectedPackage.value, selectedPid.value);
    if (success) {
      monitoringStartTime.value = new Date();
      
      durationTimer = setInterval(() => {
        updateDuration();
      }, 1000);
      
      ElMessage.success(`Started monitoring ${selectedPackage.value}`);
    } else {
      ElMessage.error('Failed to start monitoring');
    }
  } catch (error) {
    console.error('Error starting monitoring:', error);
    ElMessage.error('Failed to start monitoring: ' + error.message);
  } finally {
    isLoading.value = false;
  }
};

const stopMonitor = () => {
  stopMonitoringAPI();
  
  if (durationTimer) {
    clearInterval(durationTimer);
    durationTimer = null;
  }
  
  ElMessage.info('Performance monitoring stopped');
  checkDataConsistency();
};

const stopMonitoring = stopMonitor;

/**
 * Check data consistency
 */
const checkDataConsistency = () => {
  const timeStampsLength = performanceStore.timeStamps.length;
  if (timeStampsLength === 0) return;
  
  const dataLengths = {
    timeStamps: timeStampsLength,
    cpuApp: performanceStore.cpuAppHistory.length,
    cpuSystem: performanceStore.cpuSystemHistory.length,
    memoryTotal: performanceStore.memoryTotalHistory.length,
    batteryLevel: performanceStore.batteryLevelHistory.length,
    batteryTemperature: performanceStore.batteryTemperatureHistory.length,
    networkRx: performanceStore.networkRxHistory.length,
    networkTx: performanceStore.networkTxHistory.length,
    fps: performanceStore.fpsHistory.length,
    jankCount: performanceStore.jankCountHistory.length
  };
  
  const allEqual = Object.values(dataLengths).every(len => len === timeStampsLength);
  
  if (!allEqual) {
    console.warn('Data lengths inconsistent, may affect chart rendering:', dataLengths);
    
    Object.entries(dataLengths).forEach(([key, length]) => {
      if (key !== 'timeStamps' && length !== timeStampsLength) {
        console.warn(`${key} length (${length}) differs from timeStamps (${timeStampsLength})`);
      }
    });
  } else {
    console.log('Data consistency check passed:', timeStampsLength);
  }
};

/**
 * Export performance data as CSV
 */
const exportData = () => {
  if (performanceStore.timeStamps.length === 0) {
    ElMessage.warning('No data available to export');
    return;
  }
  
  checkDataConsistency();
  
  let csvContent = 'Timestamp,CPU App(%),CPU System(%),Memory(MB),Battery(%),Temperature(°C),Network Download(KB/s),Network Upload(KB/s),FPS,Jank Count\n';
  
  const timeStamps = performanceStore.timeStamps;
  for (let i = 0; i < timeStamps.length; i++) {
    const row = [
      timeStamps[i],
      performanceStore.cpuAppHistory[i] || '',
      performanceStore.cpuSystemHistory[i] || '',
      performanceStore.memoryTotalHistory[i] || '',
      performanceStore.batteryLevelHistory[i] || '',
      performanceStore.batteryTemperatureHistory[i] || '',
      performanceStore.networkRxHistory[i] || '',
      performanceStore.networkTxHistory[i] || '',
      performanceStore.fpsHistory[i] || '',
      performanceStore.jankCountHistory[i] || ''
    ].join(',');
    
    csvContent += row + '\n';
  }
  
  const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  const url = URL.createObjectURL(blob);
  
  link.setAttribute('href', url);
  link.setAttribute('download', `performance_data_${selectedPackage.value}_${new Date().toISOString().replace(/:/g, '-')}.csv`);
  link.style.visibility = 'hidden';
  
  document.body.appendChild(link);
  link.click();
  
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
  
  ElMessage.success('Data exported successfully');
};

// Set max data points
const updateMaxDataPoints = (value) => {
  performanceStore.setMaxDataPoints(value);
  
  const message = value === 0 
    ? 'Set to unlimited data points. Extended monitoring may consume more memory.' 
    : `Maximum data points set to ${value}`;
  
  ElMessage.success(message);
};

// Update monitoring duration
const updateDuration = () => {
  if (!monitoringStartTime.value) return;
  
  const now = new Date();
  const diff = now - monitoringStartTime.value;
  
  // 格式化持续时间
  const seconds = Math.floor(diff / 1000) % 60;
  const minutes = Math.floor(diff / (1000 * 60)) % 60;
  const hours = Math.floor(diff / (1000 * 60 * 60));
  
  monitoringDuration.value = `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
};

// 生命周期钩子
onMounted(async () => {
  // 初始化监控器
  initMonitor();
  
  // 设置初始最大数据点数量
  localMaxDataPoints.value = performanceStore.maxDataPoints || 300;
  performanceStore.setMaxDataPoints(localMaxDataPoints.value);
  
  // 加载应用列表
  await refreshAppList();
});


</script>

<style scoped>
.performance-page {
  padding: 0;
  width: 100%;
  height: 100%;
}

.container {
  width: 100%;
  max-width: none;
  padding: 20px;
}

.control-panel-card {
  --el-card-padding: 20px;
  border-radius: 12px;
  box-shadow: 0 10px 30px -15px rgba(0, 0, 0, 0.1);
  overflow: visible;
}

.panel-container {
  display: flex;
  gap: 30px;
}

.left-panel {
  flex: 2; /* 左侧占更多空间 */
  padding-right: 20px;
}

.right-panel {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  position: relative;
  border-left: 1px solid #ebeef5;
  padding-left: 20px;
}

.settings-group {
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.setting-item {
  display: flex;
  align-items: center;
  gap: 12px;
}

.setting-item .label {
  font-size: 14px;
  color: var(--el-text-color-secondary);
  display: flex;
  align-items: center;
  gap: 6px;
  white-space: nowrap;
}

.full-width {
  flex-grow: 1;
}

.option-pkg {
  font-size: 12px;
  color: var(--el-text-color-secondary);
  margin-left: 8px;
  float: right;
}

.status-display {
  padding: 12px 20px;
  background-color: #f8f9fa;
  border: 1px solid #e9ecef;
  border-radius: 8px;
  min-width: 280px;
  margin-bottom: 30px;
  width: 100%;
  text-align: center;
}

.action-buttons-container {
  display: flex;
  justify-content: center;
  width: 100%;
}

.action-buttons {
  display: flex;
  gap: 20px;
  flex-shrink: 0;
  margin-top: 10px;
}

.action-btn {
  height: 40px;
  font-size: 14px;
}

.idle-status {
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--el-text-color-secondary);
  justify-content: center;
}

.monitoring-status {
  display: flex;
  flex-direction: column;
  gap: 4px;
  font-weight: 500;
}

.app-name {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 16px;
  color: var(--el-text-color-primary);
  justify-content: center;
}

.duration {
  font-size: 14px;
  color: var(--el-text-color-secondary);
  text-align: center;
}

.live-stats {
  margin-top: 20px;
  padding-top: 10px;
}

.live-stats .el-statistic__head {
  color: var(--el-text-color-secondary);
  font-size: 14px;
}

.live-stats .el-statistic__content {
  font-size: 28px;
  font-weight: 600;
  color: var(--el-text-color-primary);
}

.data-info {
  margin-top: 8px;
  display: flex;
  justify-content: flex-end;
}

.data-point-info {
  display: flex;
  align-items: center;
  gap: 5px;
  font-size: 12px;
  color: var(--el-text-color-secondary);
}

.info-icon {
  color: var(--el-color-info);
  cursor: help;
}

.chart-card {
  min-height: 400px;
  border-radius: 12px;
  border: 1px solid var(--el-border-color-lighter);
}

.chart-placeholder {
  height: 300px;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 100%;
}

.chart-empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: var(--el-text-color-secondary);
  background: #f9f9fb;
  height: 300px;
  width: 100%;
  border-radius: 8px;
}

.empty-chart-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 30px;
  background-color: white;
  border-radius: 12px;
  box-shadow: 0 2px 12px 0 rgba(0, 0, 0, 0.05);
  width: 80%;
  max-width: 300px;
  transition: transform 0.3s ease;
}

.empty-chart-container:hover {
  transform: translateY(-5px);
}

.empty-icon {
  font-size: 56px;
  margin-bottom: 20px;
  color: #C0C4CC;
  background-color: #f5f7fa;
  padding: 20px;
  border-radius: 50%;
  box-shadow: 0 0 10px rgba(0, 0, 0, 0.05);
}

.empty-text {
  font-size: 14px;
  text-align: center;
  color: #909399;
}

/* 响应式调整 */
@media (max-width: 992px) {
  .panel-container {
    flex-direction: column;
  }
  
  .right-panel {
    border-left: none;
    border-top: 1px solid #ebeef5;
    padding-left: 0;
    padding-top: 20px;
    margin-top: 20px;
  }
  
  .status-display {
    margin-top: 0;
  }
  
  .action-buttons {
    margin-top: 20px;
  }
}

/* 前台应用信息卡片样式 */
.foreground-app-card {
  border: 1px solid #e4e7ed;
  border-radius: 8px;
  background: #fafbfc;
}

.foreground-app-card .card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin: 0;
}

.foreground-app-card .title {
  font-weight: 600;
  font-size: 14px;
  color: #303133;
}

.app-details {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 4px 0;
}

.detail-row .label {
  font-weight: 500;
  color: #606266;
  font-size: 13px;
  min-width: 70px;
}

.detail-row .value {
  color: #303133;
  font-size: 13px;
  word-break: break-all;
  text-align: right;
  flex: 1;
  margin-left: 12px;
}

.no-app {
  text-align: center;
  padding: 8px 0;
}

.no-app-text {
  color: #909399;
  font-size: 13px;
}
</style> 