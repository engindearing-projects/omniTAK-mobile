import { Component } from 'valdi_core/src/Component';
import { Label, View, Button, ScrollView } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { systemFont } from 'valdi_core/src/SystemFont';

export interface Plugin {
  id: string;
  name: string;
  description: string;
  version: string;
  author: string;
  enabled: boolean;
  installed: boolean;
  category: 'mapping' | 'tools' | 'communication' | 'sensors' | 'other';
}

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'PluginManagementViewModel',
 *   android: 'com.engindearing.omnitak.PluginManagementViewModel'
 * })
 */
export interface PluginManagementViewModel {
  installedPlugins: Plugin[];
  availablePlugins: Plugin[];
  selectedTab: 'installed' | 'available';
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'PluginManagementContext',
 *   android: 'com.engindearing.omnitak.PluginManagementContext'
 * })
 */
export interface PluginManagementContext {
  onBack?: () => void;
  onEnablePlugin?: (pluginId: string) => void;
  onDisablePlugin?: (pluginId: string) => void;
  onInstallPlugin?: (pluginId: string) => void;
  onUninstallPlugin?: (pluginId: string) => void;
  onPluginSettings?: (pluginId: string) => void;
  onTabChange?: (tab: 'installed' | 'available') => void;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'PluginManagementScreen',
 *   android: 'com.engindearing.omnitak.PluginManagementScreen'
 * })
 *
 * ATAK-style plugin management screen.
 * Allows users to view, install, enable/disable, and configure plugins.
 */
export class PluginManagementScreen extends Component<
  PluginManagementViewModel,
  PluginManagementContext
> {
  onCreate(): void {
    console.log('PluginManagementScreen onCreate');
  }

  onRender(): void {
    const { installedPlugins, availablePlugins, selectedTab } = this.viewModel;
    const plugins = selectedTab === 'installed' ? installedPlugins : availablePlugins;

    <view style={styles.container}>
      {/* Header */}
      <view style={styles.header}>
        <view style={styles.backButton} onClick={this.handleBack.bind(this)}>
          <label value="←" font={systemFont(24)} color="#FFFFFF" />
        </view>
        <label
          value="Plugins"
          font={systemFont(20, 'bold')}
          color="#FFFFFF"
        />
        <view width={40} /> {/* Spacer */}
      </view>

      {/* Tab bar */}
      <view style={styles.tabBar}>
        <view
          style={selectedTab === 'installed' ? styles.tabActive : styles.tab}
          onClick={() => this.handleTabChange('installed')}
        >
          <label
            value="Installed"
            font={systemFont(14, selectedTab === 'installed' ? 'bold' : 'regular')}
            color={selectedTab === 'installed' ? '#FFFC00' : '#CCCCCC'}
          />
          <label
            value={`(${installedPlugins.length})`}
            font={systemFont(12)}
            color={selectedTab === 'installed' ? '#FFFC00' : '#999999'}
            marginLeft={4}
          />
        </view>
        <view
          style={selectedTab === 'available' ? styles.tabActive : styles.tab}
          onClick={() => this.handleTabChange('available')}
        >
          <label
            value="Available"
            font={systemFont(14, selectedTab === 'available' ? 'bold' : 'regular')}
            color={selectedTab === 'available' ? '#FFFC00' : '#CCCCCC'}
          />
          <label
            value={`(${availablePlugins.length})`}
            font={systemFont(12)}
            color={selectedTab === 'available' ? '#FFFC00' : '#999999'}
            marginLeft={4}
          />
        </view>
      </view>

      {/* Plugin list */}
      <ScrollView style={styles.scrollView}>
        <view style={styles.content}>
          {plugins.length === 0 ? (
            <view style={styles.emptyState}>
              <label
                value={selectedTab === 'installed' ? 'No plugins installed' : 'No plugins available'}
                font={systemFont(16)}
                color="#999999"
                marginBottom={8}
              />
              <label
                value={selectedTab === 'installed' ? 'Browse available plugins to get started' : 'Check back later for new plugins'}
                font={systemFont(14)}
                color="#666666"
              />
            </view>
          ) : (
            plugins.map((plugin) => this.renderPluginItem(plugin))
          )}
        </view>
      </ScrollView>
    </view>;
  }

  private renderPluginItem(plugin: Plugin): void {
    const categoryEmoji = this.getCategoryEmoji(plugin.category);

    <view style={styles.pluginItem}>
      {/* Plugin info */}
      <view style={styles.pluginInfo}>
        <view style={styles.pluginHeader}>
          <label value={categoryEmoji} font={systemFont(20)} marginRight={8} />
          <label
            value={plugin.name}
            font={systemFont(16, 'bold')}
            color="#FFFFFF"
          />
          {plugin.enabled && (
            <view style={styles.enabledBadge}>
              <label
                value="ACTIVE"
                font={systemFont(10, 'bold')}
                color="#4CAF50"
              />
            </view>
          )}
        </view>

        <label
          value={plugin.description}
          font={systemFont(14)}
          color="#CCCCCC"
          marginTop={6}
        />

        <view style={styles.pluginMeta}>
          <label
            value={`v${plugin.version}`}
            font={systemFont(12)}
            color="#999999"
          />
          <label
            value="•"
            font={systemFont(12)}
            color="#666666"
            marginHorizontal={8}
          />
          <label
            value={plugin.author}
            font={systemFont(12)}
            color="#999999"
          />
          <label
            value="•"
            font={systemFont(12)}
            color="#666666"
            marginHorizontal={8}
          />
          <label
            value={plugin.category}
            font={systemFont(12)}
            color="#999999"
          />
        </view>
      </view>

      {/* Action buttons */}
      <view style={styles.pluginActions}>
        {plugin.installed ? (
          <>
            {plugin.enabled ? (
              <view
                style={styles.actionButton}
                onClick={() => this.handleDisable(plugin.id)}
              >
                <label
                  value="Disable"
                  font={systemFont(12, 'bold')}
                  color="#FF9800"
                />
              </view>
            ) : (
              <view
                style={styles.actionButton}
                onClick={() => this.handleEnable(plugin.id)}
              >
                <label
                  value="Enable"
                  font={systemFont(12, 'bold')}
                  color="#4CAF50"
                />
              </view>
            )}

            <view
              style={styles.iconButton}
              onClick={() => this.handleSettings(plugin.id)}
            >
              <label value="⚙️" font={systemFont(16)} />
            </view>

            <view
              style={styles.iconButton}
              onClick={() => this.handleUninstall(plugin.id)}
            >
              <label value="🗑️" font={systemFont(16)} />
            </view>
          </>
        ) : (
          <view
            style={styles.actionButtonPrimary}
            onClick={() => this.handleInstall(plugin.id)}
          >
            <label
              value="Install"
              font={systemFont(12, 'bold')}
              color="#1E1E1E"
            />
          </view>
        )}
      </view>
    </view>;
  }

  private getCategoryEmoji(category: string): string {
    switch (category) {
      case 'mapping':
        return '🗺️';
      case 'tools':
        return '🛠️';
      case 'communication':
        return '📡';
      case 'sensors':
        return '📊';
      default:
        return '🔌';
    }
  }

  private handleBack(): void {
    if (this.context.onBack) {
      this.context.onBack();
    }
  }

  private handleTabChange(tab: 'installed' | 'available'): void {
    if (this.context.onTabChange) {
      this.context.onTabChange(tab);
    }
  }

  private handleEnable(pluginId: string): void {
    if (this.context.onEnablePlugin) {
      this.context.onEnablePlugin(pluginId);
    }
  }

  private handleDisable(pluginId: string): void {
    if (this.context.onDisablePlugin) {
      this.context.onDisablePlugin(pluginId);
    }
  }

  private handleInstall(pluginId: string): void {
    if (this.context.onInstallPlugin) {
      this.context.onInstallPlugin(pluginId);
    }
  }

  private handleUninstall(pluginId: string): void {
    if (this.context.onUninstallPlugin) {
      this.context.onUninstallPlugin(pluginId);
    }
  }

  private handleSettings(pluginId: string): void {
    if (this.context.onPluginSettings) {
      this.context.onPluginSettings(pluginId);
    }
  }
}

const styles = {
  container: new Style<View>({
    width: '100%',
    height: '100%',
    backgroundColor: '#1E1E1E',
    flexDirection: 'column',
  }),

  header: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    paddingTop: 60,
    backgroundColor: '#2A2A2A',
    borderBottomWidth: 1,
    borderBottomColor: '#3A3A3A',
  }),

  backButton: new Style<View>({
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  tabBar: new Style<View>({
    flexDirection: 'row',
    backgroundColor: '#2A2A2A',
    borderBottomWidth: 1,
    borderBottomColor: '#3A3A3A',
  }),

  tab: new Style<View>({
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
    cursor: 'pointer',
  }),

  tabActive: new Style<View>({
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
    borderBottomWidth: 3,
    borderBottomColor: '#FFFC00',
    cursor: 'pointer',
  }),

  scrollView: new Style<ScrollView>({
    flex: 1,
  }),

  content: new Style<View>({
    padding: 16,
  }),

  emptyState: new Style<View>({
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  }),

  pluginItem: new Style<View>({
    backgroundColor: '#2A2A2A',
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
  }),

  pluginInfo: new Style<View>({
    marginBottom: 12,
  }),

  pluginHeader: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
  }),

  enabledBadge: new Style<View>({
    marginLeft: 8,
    paddingHorizontal: 8,
    paddingVertical: 2,
    backgroundColor: 'rgba(76, 175, 80, 0.2)',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#4CAF50',
  }),

  pluginMeta: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 8,
  }),

  pluginActions: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: 8,
  }),

  actionButton: new Style<View>({
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#3A3A3A',
    borderRadius: 4,
    cursor: 'pointer',
  }),

  actionButtonPrimary: new Style<View>({
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: '#FFFC00',
    borderRadius: 4,
    cursor: 'pointer',
  }),

  iconButton: new Style<View>({
    width: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#3A3A3A',
    borderRadius: 4,
    cursor: 'pointer',
  }),
};
