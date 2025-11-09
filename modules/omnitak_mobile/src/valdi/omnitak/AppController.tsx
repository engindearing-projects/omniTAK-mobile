import { Component } from 'valdi_core/src/Component';
import { View } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { NavigationDrawer, NavigationItem } from './components/NavigationDrawer';
import { EnhancedMapScreen } from './screens/EnhancedMapScreen';
import { SettingsScreen, SettingsItem } from './screens/SettingsScreen';
import { ServerManagementScreen, ServerConnection } from './screens/ServerManagementScreen';
import { PluginManagementScreen, Plugin } from './screens/PluginManagementScreen';

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'AppControllerViewModel',
 *   android: 'com.engindearing.omnitak.AppControllerViewModel'
 * })
 */
export interface AppControllerViewModel {
  currentScreen: NavigationItem;
  drawerOpen: boolean;
  userName: string;
  userCallsign: string;
  connectionStatus: string;

  // Settings data
  settings: SettingsItem[];

  // Server data
  servers: ServerConnection[];
  showAddServerDialog: boolean;

  // Plugin data
  installedPlugins: Plugin[];
  availablePlugins: Plugin[];
  selectedPluginTab: 'installed' | 'available';

  // Map data
  markerCount: number;
  lastUpdate: string;
  isConnected: boolean;
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'AppControllerContext',
 *   android: 'com.engindearing.omnitak.AppControllerContext'
 * })
 */
export interface AppControllerContext {
  isDebugMode?: boolean;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'AppController',
 *   android: 'com.engindearing.omnitak.AppController'
 * })
 *
 * Main application controller that manages navigation between screens.
 * Implements ATAK-style navigation with drawer menu and multiple screens.
 */
export class AppController extends Component<
  AppControllerViewModel,
  AppControllerContext
> {
  onCreate(): void {
    console.log('AppController onCreate');
    this.initializeDefaultData();
  }

  onRender(): void {
    const { currentScreen, drawerOpen } = this.viewModel;

    <view style={styles.container}>
      {/* Current Screen */}
      {this.renderCurrentScreen(currentScreen)}

      {/* Navigation Drawer Overlay */}
      {drawerOpen && this.renderDrawer()}
    </view>;
  }

  private renderCurrentScreen(screen: NavigationItem): void {
    switch (screen) {
      case 'map':
        this.renderMapScreen();
        break;
      case 'settings':
        this.renderSettingsScreen();
        break;
      case 'servers':
        this.renderServerScreen();
        break;
      case 'plugins':
        this.renderPluginScreen();
        break;
      case 'tools':
        this.renderToolsScreen();
        break;
      case 'about':
        this.renderAboutScreen();
        break;
      default:
        this.renderMapScreen();
    }
  }

  private renderMapScreen(): void {
    <EnhancedMapScreen
      viewModel={{
        markerCount: this.viewModel.markerCount,
        lastUpdate: this.viewModel.lastUpdate,
        isConnected: this.viewModel.isConnected,
        markers: [],
        camera: {
          latitude: 38.8977,
          longitude: -77.0365,
          zoom: 10,
          bearing: 0,
        },
        isLocked: false,
        orientation: 'portrait',
        northUp: true,
        measureMode: 'none',
        measurePoints: [],
      }}
      context={{
        onOpenMenu: this.handleOpenDrawer.bind(this),
        onOverflowMenu: this.handleOverflowMenu.bind(this),
      }}
    />;
  }

  private renderSettingsScreen(): void {
    <SettingsScreen
      viewModel={{
        settings: this.viewModel.settings,
      }}
      context={{
        onBack: () => this.handleNavigate('map'),
        onSettingChange: this.handleSettingChange.bind(this),
      }}
    />;
  }

  private renderServerScreen(): void {
    <ServerManagementScreen
      viewModel={{
        servers: this.viewModel.servers,
        showAddDialog: this.viewModel.showAddServerDialog,
      }}
      context={{
        onBack: () => this.handleNavigate('map'),
        onConnect: this.handleServerConnect.bind(this),
        onDisconnect: this.handleServerDisconnect.bind(this),
        onAddServer: this.handleAddServer.bind(this),
        onEditServer: this.handleEditServer.bind(this),
        onDeleteServer: this.handleDeleteServer.bind(this),
        onShowAddDialog: () => this.updateViewModel({ showAddServerDialog: true }),
        onHideAddDialog: () => this.updateViewModel({ showAddServerDialog: false }),
      }}
    />;
  }

  private renderPluginScreen(): void {
    <PluginManagementScreen
      viewModel={{
        installedPlugins: this.viewModel.installedPlugins,
        availablePlugins: this.viewModel.availablePlugins,
        selectedTab: this.viewModel.selectedPluginTab,
      }}
      context={{
        onBack: () => this.handleNavigate('map'),
        onEnablePlugin: this.handleEnablePlugin.bind(this),
        onDisablePlugin: this.handleDisablePlugin.bind(this),
        onInstallPlugin: this.handleInstallPlugin.bind(this),
        onUninstallPlugin: this.handleUninstallPlugin.bind(this),
        onPluginSettings: this.handlePluginSettings.bind(this),
        onTabChange: (tab) => this.updateViewModel({ selectedPluginTab: tab }),
      }}
    />;
  }

  private renderToolsScreen(): void {
    // TODO: Implement tools screen
    <view style={styles.placeholderScreen}>
      <label value="Tools Screen - Coming Soon" />
    </view>;
  }

  private renderAboutScreen(): void {
    // TODO: Implement about screen
    <view style={styles.placeholderScreen}>
      <label value="About Screen - Coming Soon" />
    </view>;
  }

  private renderDrawer(): void {
    const { userName, userCallsign, connectionStatus, currentScreen } = this.viewModel;

    <NavigationDrawer
      viewModel={{
        isOpen: true,
        currentScreen,
        userName,
        userCallsign,
        connectionStatus,
      }}
      context={{
        onNavigate: this.handleNavigate.bind(this),
        onClose: this.handleCloseDrawer.bind(this),
      }}
    />;
  }

  private initializeDefaultData(): void {
    // Initialize default settings
    const defaultSettings: SettingsItem[] = [
      { id: 'general', title: 'General', type: 'section' },
      {
        id: 'callsign',
        title: 'Callsign',
        description: 'Your tactical callsign',
        value: 'ALPHA-1',
        type: 'option',
      },
      {
        id: 'uid',
        title: 'UID',
        description: 'Unique identifier',
        value: 'iTAK-001',
        type: 'option',
      },
      { id: 'display', title: 'Display', type: 'section' },
      {
        id: 'darkMode',
        title: 'Dark Mode',
        description: 'Use dark color scheme',
        type: 'toggle',
        enabled: true,
      },
      {
        id: 'showGrid',
        title: 'Show Grid',
        description: 'Display coordinate grid on map',
        type: 'toggle',
        enabled: false,
      },
      { id: 'network', title: 'Network', type: 'section' },
      {
        id: 'autoConnect',
        title: 'Auto-connect',
        description: 'Automatically connect to last server',
        type: 'toggle',
        enabled: true,
      },
      { id: 'location', title: 'Location', type: 'section' },
      {
        id: 'gpsEnabled',
        title: 'GPS Enabled',
        description: 'Use device GPS for location',
        type: 'toggle',
        enabled: true,
      },
      {
        id: 'shareLocation',
        title: 'Share Location',
        description: 'Broadcast location to TAK server',
        type: 'toggle',
        enabled: true,
      },
    ];

    // Initialize default servers
    const defaultServers: ServerConnection[] = [
      {
        id: 'server-1',
        name: 'TAK Server (Local)',
        host: '192.168.1.100',
        port: 8087,
        protocol: 'tcp',
        status: 'disconnected',
      },
      {
        id: 'server-2',
        name: 'TAK Server (Cloud)',
        host: 'tak.example.com',
        port: 8089,
        protocol: 'ssl',
        status: 'disconnected',
      },
    ];

    // Initialize default plugins
    const installedPlugins: Plugin[] = [
      {
        id: 'plugin-1',
        name: 'Weather Overlay',
        description: 'Display weather data on the map',
        version: '1.2.0',
        author: 'iTAK Team',
        enabled: true,
        installed: true,
        category: 'mapping',
      },
      {
        id: 'plugin-2',
        name: 'Route Planning',
        description: 'Plan and share tactical routes',
        version: '2.0.1',
        author: 'iTAK Team',
        enabled: false,
        installed: true,
        category: 'tools',
      },
    ];

    const availablePlugins: Plugin[] = [
      {
        id: 'plugin-3',
        name: 'Voice Chat',
        description: 'Encrypted voice communication',
        version: '1.0.0',
        author: 'Community',
        enabled: false,
        installed: false,
        category: 'communication',
      },
      {
        id: 'plugin-4',
        name: 'Sensor Integration',
        description: 'Connect external sensors',
        version: '0.9.0',
        author: 'Community',
        enabled: false,
        installed: false,
        category: 'sensors',
      },
    ];

    this.updateViewModel({
      settings: defaultSettings,
      servers: defaultServers,
      installedPlugins,
      availablePlugins,
      selectedPluginTab: 'installed',
      userName: 'Tactical User',
      userCallsign: 'ALPHA-1',
      connectionStatus: 'DISCONNECTED',
      currentScreen: 'map',
      drawerOpen: false,
      markerCount: 0,
      lastUpdate: 'Never',
      isConnected: false,
      showAddServerDialog: false,
    });
  }

  private handleNavigate(screen: NavigationItem): void {
    console.log('Navigate to:', screen);
    this.updateViewModel({
      currentScreen: screen,
      drawerOpen: false,
    });
  }

  private handleOpenDrawer(): void {
    console.log('Open drawer');
    this.updateViewModel({ drawerOpen: true });
  }

  private handleCloseDrawer(): void {
    console.log('Close drawer');
    this.updateViewModel({ drawerOpen: false });
  }

  private handleOverflowMenu(): void {
    console.log('Open overflow menu');
    // TODO: Implement overflow menu
  }

  private handleSettingChange(id: string, value: any): void {
    console.log('Setting changed:', id, value);
    const updatedSettings = this.viewModel.settings.map((setting) =>
      setting.id === id ? { ...setting, enabled: value } : setting
    );
    this.updateViewModel({ settings: updatedSettings });
  }

  private handleServerConnect(serverId: string): void {
    console.log('Connect to server:', serverId);
    const updatedServers = this.viewModel.servers.map((server) =>
      server.id === serverId
        ? { ...server, status: 'connecting' as const }
        : server
    );
    this.updateViewModel({ servers: updatedServers });

    // Simulate connection
    setTimeout(() => {
      const connectedServers = this.viewModel.servers.map((server) =>
        server.id === serverId
          ? {
              ...server,
              status: 'connected' as const,
              lastConnected: new Date().toLocaleString(),
            }
          : server
      );
      this.updateViewModel({
        servers: connectedServers,
        connectionStatus: 'CONNECTED',
        isConnected: true,
      });
    }, 1500);
  }

  private handleServerDisconnect(serverId: string): void {
    console.log('Disconnect from server:', serverId);
    const updatedServers = this.viewModel.servers.map((server) =>
      server.id === serverId
        ? { ...server, status: 'disconnected' as const }
        : server
    );
    this.updateViewModel({
      servers: updatedServers,
      connectionStatus: 'DISCONNECTED',
      isConnected: false,
    });
  }

  private handleAddServer(server: Partial<ServerConnection>): void {
    console.log('Add server:', server);
    const newServer: ServerConnection = {
      id: `server-${Date.now()}`,
      name: server.name || 'New Server',
      host: server.host || 'localhost',
      port: server.port || 8087,
      protocol: server.protocol || 'tcp',
      status: 'disconnected',
    };
    this.updateViewModel({
      servers: [...this.viewModel.servers, newServer],
      showAddServerDialog: false,
    });
  }

  private handleEditServer(serverId: string): void {
    console.log('Edit server:', serverId);
    // TODO: Open edit dialog
  }

  private handleDeleteServer(serverId: string): void {
    console.log('Delete server:', serverId);
    const updatedServers = this.viewModel.servers.filter(
      (server) => server.id !== serverId
    );
    this.updateViewModel({ servers: updatedServers });
  }

  private handleEnablePlugin(pluginId: string): void {
    console.log('Enable plugin:', pluginId);
    const updatedPlugins = this.viewModel.installedPlugins.map((plugin) =>
      plugin.id === pluginId ? { ...plugin, enabled: true } : plugin
    );
    this.updateViewModel({ installedPlugins: updatedPlugins });
  }

  private handleDisablePlugin(pluginId: string): void {
    console.log('Disable plugin:', pluginId);
    const updatedPlugins = this.viewModel.installedPlugins.map((plugin) =>
      plugin.id === pluginId ? { ...plugin, enabled: false } : plugin
    );
    this.updateViewModel({ installedPlugins: updatedPlugins });
  }

  private handleInstallPlugin(pluginId: string): void {
    console.log('Install plugin:', pluginId);
    const pluginToInstall = this.viewModel.availablePlugins.find(
      (p) => p.id === pluginId
    );
    if (pluginToInstall) {
      const installedPlugin = { ...pluginToInstall, installed: true };
      this.updateViewModel({
        installedPlugins: [...this.viewModel.installedPlugins, installedPlugin],
        availablePlugins: this.viewModel.availablePlugins.filter(
          (p) => p.id !== pluginId
        ),
      });
    }
  }

  private handleUninstallPlugin(pluginId: string): void {
    console.log('Uninstall plugin:', pluginId);
    const pluginToUninstall = this.viewModel.installedPlugins.find(
      (p) => p.id === pluginId
    );
    if (pluginToUninstall) {
      const uninstalledPlugin = {
        ...pluginToUninstall,
        installed: false,
        enabled: false,
      };
      this.updateViewModel({
        installedPlugins: this.viewModel.installedPlugins.filter(
          (p) => p.id !== pluginId
        ),
        availablePlugins: [...this.viewModel.availablePlugins, uninstalledPlugin],
      });
    }
  }

  private handlePluginSettings(pluginId: string): void {
    console.log('Open plugin settings:', pluginId);
    // TODO: Open plugin settings dialog
  }

  private updateViewModel(updates: Partial<AppControllerViewModel>): void {
    console.log('ViewModel update requested:', updates);
    this.scheduleRender();
  }
}

const styles = {
  container: new Style<View>({
    width: '100%',
    height: '100%',
    backgroundColor: '#1E1E1E',
  }),

  placeholderScreen: new Style<View>({
    width: '100%',
    height: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#1E1E1E',
  }),
};
