import { Component } from 'valdi_core/src/Component';
import { Label, View, Button } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { systemFont } from 'valdi_core/src/SystemFont';

export type NavigationItem = 'map' | 'settings' | 'servers' | 'plugins' | 'tools' | 'about';

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'NavigationDrawerViewModel',
 *   android: 'com.engindearing.omnitak.NavigationDrawerViewModel'
 * })
 */
export interface NavigationDrawerViewModel {
  isOpen: boolean;
  currentScreen: NavigationItem;
  userName: string;
  userCallsign: string;
  connectionStatus: string;
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'NavigationDrawerContext',
 *   android: 'com.engindearing.omnitak.NavigationDrawerContext'
 * })
 */
export interface NavigationDrawerContext {
  onNavigate?: (screen: NavigationItem) => void;
  onClose?: () => void;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'NavigationDrawer',
 *   android: 'com.engindearing.omnitak.NavigationDrawer'
 * })
 *
 * ATAK-style navigation drawer with menu items for settings, servers, plugins, etc.
 */
export class NavigationDrawer extends Component<
  NavigationDrawerViewModel,
  NavigationDrawerContext
> {
  onCreate(): void {
    console.log('NavigationDrawer onCreate');
  }

  onRender(): void {
    const { isOpen, currentScreen, userName, userCallsign, connectionStatus } = this.viewModel;

    if (!isOpen) {
      return;
    }

    <view style={styles.overlay} onClick={this.handleOverlayClick.bind(this)}>
      {/* Drawer panel with slide-in animation */}
      <view
        style={isOpen ? styles.drawerOpen : styles.drawer}
        onClick={this.handleDrawerClick.bind(this)}
      >
        {/* Header with user info - ATAK Style */}
        <view style={styles.header}>
          {/* iTAK Logo with underline */}
          <view style={styles.logoContainer}>
            <label
              value="iTAK"
              font={systemFont(24, 'bold')}
              color="#FFFC00"
            />
            <view style={styles.logoUnderline} />
          </view>

          {/* User Info */}
          <view style={styles.userInfo}>
            <label
              value="👤"
              font={systemFont(14)}
              marginRight={8}
            />
            <view>
              <label
                value={userCallsign || 'ALPHA-1'}
                font={systemFont(14, 'bold')}
                color="#FFFFFF"
              />
              <label
                value={userName || 'User'}
                font={systemFont(11)}
                color="#CCCCCC"
                marginTop={2}
              />
            </view>
          </view>

          {/* Connection status with LED indicator */}
          <view style={styles.connectionStatus}>
            <view style={styles.connectionLed}>
              <view
                width={10}
                height={10}
                borderRadius={5}
                backgroundColor={this.getConnectionColor(connectionStatus)}
                shadowColor={this.getConnectionColor(connectionStatus)}
                shadowOffset={{ width: 0, height: 0 }}
                shadowOpacity={0.8}
                shadowRadius={4}
              />
            </view>
            <view style={styles.connectionText}>
              <label
                value="STATUS"
                font={systemFont(8, 'bold')}
                color="#999999"
              />
              <label
                value={this.getConnectionText(connectionStatus)}
                font={systemFont(11, 'bold')}
                color={this.getConnectionColor(connectionStatus)}
                marginTop={2}
              />
            </view>
          </view>
        </view>

        {/* Menu items */}
        <view style={styles.menuItems}>
          {this.renderMenuItem('🗺️', 'Map', 'map', currentScreen === 'map')}
          {this.renderMenuItem('⚙️', 'Settings', 'settings', currentScreen === 'settings')}
          {this.renderMenuItem('🌐', 'Network Connections', 'servers', currentScreen === 'servers')}
          {this.renderMenuItem('🔌', 'Plugins', 'plugins', currentScreen === 'plugins')}
          {this.renderMenuItem('🛠️', 'Tools', 'tools', currentScreen === 'tools')}
          {this.renderDivider()}
          {this.renderMenuItem('ℹ️', 'About', 'about', currentScreen === 'about')}
        </view>

        {/* Footer */}
        <view style={styles.footer}>
          <label
            value="Powered by Valdi + omni-TAK"
            font={systemFont(9)}
            color="#666666"
          />
          <label
            value="v1.0.0"
            font={systemFont(9)}
            color="#666666"
            marginTop={2}
          />
        </view>
      </view>
    </view>;
  }

  private renderMenuItem(
    icon: string,
    title: string,
    screen: NavigationItem,
    isActive: boolean
  ): void {
    <view
      style={isActive ? styles.menuItemActive : styles.menuItem}
      onClick={() => this.handleNavigate(screen)}
    >
      <label
        value={icon}
        font={systemFont(20)}
        marginRight={16}
      />
      <label
        value={title}
        font={systemFont(14, isActive ? 'bold' : 'regular')}
        color={isActive ? '#FFFC00' : '#FFFFFF'}
      />
    </view>;
  }

  private renderDivider(): void {
    <view style={styles.divider} />;
  }

  private handleNavigate(screen: NavigationItem): void {
    console.log('Navigate to:', screen);
    if (this.context.onNavigate) {
      this.context.onNavigate(screen);
    }
  }

  private handleOverlayClick(event: any): void {
    // Close drawer when clicking overlay
    if (this.context.onClose) {
      this.context.onClose();
    }
  }

  private handleDrawerClick(event: any): void {
    // Prevent clicks inside drawer from closing it
    event?.stopPropagation?.();
  }

  private getConnectionColor(status: string): string {
    switch (status) {
      case 'CONNECTED':
        return '#00FF00';
      case 'CONNECTING':
        return '#FFA500';
      case 'ERROR':
        return '#FF0000';
      default:
        return '#666666';
    }
  }

  private getConnectionText(status: string): string {
    switch (status) {
      case 'CONNECTED':
        return 'Connected to TAK Server';
      case 'CONNECTING':
        return 'Connecting...';
      case 'ERROR':
        return 'Connection Error';
      default:
        return 'Not Connected';
    }
  }
}

const styles = {
  overlay: new Style<View>({
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    zIndex: 1000,
    animation: 'fadeIn 0.3s ease-in-out',
  }),

  drawer: new Style<View>({
    position: 'absolute',
    top: 0,
    left: -280, // Start off-screen
    bottom: 0,
    width: 280,
    backgroundColor: '#1E1E1E',
    flexDirection: 'column',
    shadowColor: '#000000',
    shadowOffset: { width: 2, height: 0 },
    shadowOpacity: 0.5,
    shadowRadius: 12,
    borderRightWidth: 1,
    borderRightColor: '#FFFC00',
    transition: 'left 0.3s ease-in-out',
  }),

  drawerOpen: new Style<View>({
    position: 'absolute',
    top: 0,
    left: 0, // Slide in to visible position
    bottom: 0,
    width: 280,
    backgroundColor: '#1E1E1E',
    flexDirection: 'column',
    shadowColor: '#000000',
    shadowOffset: { width: 4, height: 0 },
    shadowOpacity: 0.7,
    shadowRadius: 16,
    borderRightWidth: 2,
    borderRightColor: '#FFFC00',
    transition: 'left 0.3s ease-in-out',
  }),

  header: new Style<View>({
    padding: 20,
    paddingTop: 60, // Account for status bar
    backgroundColor: '#2A2A2A',
    borderBottomWidth: 2,
    borderBottomColor: '#FFFC00',
  }),

  logoContainer: new Style<View>({
    marginBottom: 16,
  }),

  logoUnderline: new Style<View>({
    width: 60,
    height: 3,
    backgroundColor: '#FFFC00',
    marginTop: 4,
    borderRadius: 2,
  }),

  userInfo: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 16,
    padding: 12,
    backgroundColor: 'rgba(255, 252, 0, 0.1)',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: 'rgba(255, 252, 0, 0.3)',
  }),

  connectionStatus: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#1E1E1E',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#3A3A3A',
  }),

  connectionLed: new Style<View>({
    marginRight: 12,
  }),

  connectionText: new Style<View>({
    flex: 1,
  }),

  menuItems: new Style<View>({
    flex: 1,
    paddingTop: 8,
  }),

  menuItem: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    paddingLeft: 20,
    cursor: 'pointer',
  }),

  menuItemActive: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    paddingLeft: 20,
    backgroundColor: '#333333',
    borderLeftWidth: 4,
    borderLeftColor: '#FFFC00',
    cursor: 'pointer',
  }),

  divider: new Style<View>({
    height: 1,
    backgroundColor: '#3A3A3A',
    marginVertical: 8,
    marginHorizontal: 16,
  }),

  footer: new Style<View>({
    padding: 16,
    alignItems: 'center',
    borderTopWidth: 1,
    borderTopColor: '#3A3A3A',
  }),
};
