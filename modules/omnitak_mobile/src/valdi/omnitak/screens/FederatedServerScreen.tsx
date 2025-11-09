import { Component } from 'valdi_core/src/Component';
import { Label, View } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { systemFont } from 'valdi_core/src/SystemFont';
import {
  multiServerFederation,
  FederatedServer,
  DataType,
  DataSharingPolicy,
} from '../services/MultiServerFederation';
import { ServerConfig } from '../services/TakService';

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'FederatedServerScreenViewModel',
 *   android: 'com.engindearing.omnitak.FederatedServerScreenViewModel'
 * })
 */
export interface FederatedServerScreenViewModel {
  servers: FederatedServer[];
  selectedServerId: string | null;
  showAddDialog: boolean;
  showPolicyDialog: boolean;
  connectedCount: number;
  totalCount: number;
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'FederatedServerScreenContext',
 *   android: 'com.engindearing.omnitak.FederatedServerScreenContext'
 * })
 */
export interface FederatedServerScreenContext {
  onBack?: () => void;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'FederatedServerScreen',
 *   android: 'com.engindearing.omnitak.FederatedServerScreen'
 * })
 *
 * Federated Server Management Screen with multi-connection support
 * and data sharing policy configuration.
 */
export class FederatedServerScreen extends Component<
  FederatedServerScreenViewModel,
  FederatedServerScreenContext
> {
  private statusUnsubscribe?: () => void;

  onCreate(): void {
    console.log('FederatedServerScreen onCreate');
    this.loadServers();
    this.statusUnsubscribe = multiServerFederation.onStatusChange(() => {
      this.loadServers();
    });
  }

  onDestroy(): void {
    if (this.statusUnsubscribe) {
      this.statusUnsubscribe();
    }
  }

  onRender(): void {
    const {
      servers,
      selectedServerId,
      showAddDialog,
      showPolicyDialog,
      connectedCount,
      totalCount,
    } = this.viewModel;

    <view style={styles.container}>
      {/* Header */}
      <view style={styles.header}>
        <view
          style={styles.backButton}
          onClick={this.handleBack.bind(this)}
        >
          <label value="←" font={systemFont(24)} color="#FFFFFF" />
        </view>

        <view style={styles.headerContent}>
          <label
            value="Federated Servers"
            font={systemFont(20, 'bold')}
            color="#FFFC00"
          />
          <label
            value={`${connectedCount}/${totalCount} connected`}
            font={systemFont(12)}
            color="#CCCCCC"
            marginTop={4}
          />
        </view>

        <view
          style={styles.addButton}
          onClick={this.handleAddServer.bind(this)}
        >
          <label value="+" font={systemFont(28)} color="#FFFC00" />
        </view>
      </view>

      {/* Info Banner */}
      <view style={styles.infoBanner}>
        <label value="ℹ️" font={systemFont(16)} marginRight={8} />
        <view style={styles.infoBannerText}>
          <label
            value="Connect to multiple TAK servers simultaneously"
            font={systemFont(11, 'bold')}
            color="#FFFFFF"
          />
          <label
            value="Data is federated and shared based on policies"
            font={systemFont(10)}
            color="#CCCCCC"
            marginTop={2}
          />
        </view>
      </view>

      {/* Quick Actions */}
      <view style={styles.quickActions}>
        <view
          style={styles.actionButton}
          onClick={this.handleConnectAll.bind(this)}
        >
          <label value="⚡" font={systemFont(18)} />
          <label
            value="Connect All"
            font={systemFont(12, 'bold')}
            color="#4CAF50"
            marginLeft={6}
          />
        </view>

        <view
          style={styles.actionButton}
          onClick={this.handleDisconnectAll.bind(this)}
        >
          <label value="⏸" font={systemFont(18)} />
          <label
            value="Disconnect All"
            font={systemFont(12, 'bold')}
            color="#FF5252"
            marginLeft={6}
          />
        </view>
      </view>

      {/* Server List */}
      <view style={styles.serverList}>
        {servers.length === 0 && this.renderEmptyState()}
        {servers.map((server) => this.renderServerCard(server))}
      </view>
    </view>;
  }

  private renderEmptyState(): void {
    <view style={styles.emptyState}>
      <label value="📡" font={systemFont(48)} />
      <label
        value="No Servers Configured"
        font={systemFont(18, 'bold')}
        color="#FFFFFF"
        marginTop={16}
      />
      <label
        value="Add a TAK server to begin federation"
        font={systemFont(12)}
        color="#CCCCCC"
        marginTop={8}
      />
    </view>;
  }

  private renderServerCard(server: FederatedServer): void {
    const isSelected = this.viewModel.selectedServerId === server.id;

    <view
      key={server.id}
      style={isSelected ? styles.serverCardActive : styles.serverCard}
      onClick={() => this.handleSelectServer(server.id)}
    >
      {/* Server Header */}
      <view style={styles.serverHeader}>
        <view style={styles.serverHeaderLeft}>
          {/* LED Status Indicator */}
          <view
            style={this.getStatusStyle(server.status)}
          />

          <view style={styles.serverInfo}>
            <label
              value={server.name}
              font={systemFont(16, 'bold')}
              color="#FFFFFF"
            />
            <label
              value={`${server.config.host}:${server.config.port}`}
              font={systemFont(11)}
              color="#CCCCCC"
              marginTop={2}
            />
          </view>
        </view>

        {/* Connection Toggle */}
        <view
          style={styles.connectionButton}
          onClick={(e) => this.handleToggleConnection(server.id, e)}
        >
          <label
            value={server.status === 'connected' ? 'Disconnect' : 'Connect'}
            font={systemFont(12, 'bold')}
            color={server.status === 'connected' ? '#FF5252' : '#4CAF50'}
          />
        </view>
      </view>

      {/* Server Details */}
      {isSelected && (
        <view style={styles.serverDetails}>
          {/* Protocol Info */}
          <view style={styles.detailRow}>
            <label
              value="Protocol:"
              font={systemFont(11)}
              color="#999999"
            />
            <label
              value={`${server.config.protocol} ${server.config.useTls ? '(TLS)' : ''}`}
              font={systemFont(11, 'bold')}
              color="#FFFFFF"
              marginLeft={8}
            />
          </view>

          {/* Data Sharing Policy */}
          <view style={styles.policySection}>
            <label
              value="Data Sharing Policy"
              font={systemFont(13, 'bold')}
              color="#FFFC00"
              marginBottom={8}
            />

            {/* Blue Team Mode */}
            <view style={styles.policyRow}>
              <view
                style={
                  server.policy.blueTeamOnly
                    ? styles.toggleOn
                    : styles.toggleOff
                }
                onClick={() =>
                  this.handleToggleBlueTeam(server.id, !server.policy.blueTeamOnly)
                }
              >
                <label
                  value={server.policy.blueTeamOnly ? '✓' : '○'}
                  font={systemFont(12, 'bold')}
                  color={server.policy.blueTeamOnly ? '#4CAF50' : '#666666'}
                />
              </view>
              <label
                value="Blue Team Only (Friendly Forces)"
                font={systemFont(11)}
                color="#FFFFFF"
                marginLeft={8}
              />
            </view>

            {/* Auto Share */}
            <view style={styles.policyRow}>
              <view
                style={
                  server.policy.autoShare
                    ? styles.toggleOn
                    : styles.toggleOff
                }
                onClick={() =>
                  this.handleToggleAutoShare(server.id, !server.policy.autoShare)
                }
              >
                <label
                  value={server.policy.autoShare ? '✓' : '○'}
                  font={systemFont(12, 'bold')}
                  color={server.policy.autoShare ? '#4CAF50' : '#666666'}
                />
              </view>
              <label
                value="Auto-Share to Other Servers"
                font={systemFont(11)}
                color="#FFFFFF"
                marginLeft={8}
              />
            </view>

            {/* Receive Types */}
            <view style={styles.typeSection}>
              <label
                value="Receive:"
                font={systemFont(10, 'bold')}
                color="#999999"
                marginBottom={4}
              />
              <view style={styles.typeChips}>
                {this.renderTypeChips(server.policy.receiveTypes)}
              </view>
            </view>

            {/* Send Types */}
            <view style={styles.typeSection}>
              <label
                value="Send:"
                font={systemFont(10, 'bold')}
                color="#999999"
                marginBottom={4}
              />
              <view style={styles.typeChips}>
                {this.renderTypeChips(server.policy.sendTypes)}
              </view>
            </view>
          </view>

          {/* Action Buttons */}
          <view style={styles.actionRow}>
            <view
              style={styles.editButton}
              onClick={() => this.handleEditPolicy(server.id)}
            >
              <label
                value="Edit Policy"
                font={systemFont(11, 'bold')}
                color="#FFFC00"
              />
            </view>

            <view
              style={styles.deleteButton}
              onClick={() => this.handleDeleteServer(server.id)}
            >
              <label
                value="Remove"
                font={systemFont(11, 'bold')}
                color="#FF5252"
              />
            </view>
          </view>
        </view>
      )}
    </view>;
  }

  private renderTypeChips(types: DataType[]): void {
    types.forEach((type) => {
      <view key={type} style={styles.typeChip}>
        <label
          value={type}
          font={systemFont(9, 'bold')}
          color="#FFFC00"
        />
      </view>;
    });
  }

  private getStatusStyle(status: string): Style<View> {
    switch (status) {
      case 'connected':
        return styles.ledConnected;
      case 'connecting':
        return styles.ledConnecting;
      case 'error':
        return styles.ledError;
      default:
        return styles.ledDisconnected;
    }
  }

  private loadServers(): void {
    const servers = multiServerFederation.getServers();
    const connectedCount = multiServerFederation.getConnectedCount();

    this.updateViewModel({
      servers,
      connectedCount,
      totalCount: servers.length,
    });
  }

  private handleBack(): void {
    if (this.context.onBack) {
      this.context.onBack();
    }
  }

  private handleAddServer(): void {
    console.log('Add server dialog');
    // TODO: Show add server dialog
    this.updateViewModel({ showAddDialog: true });
  }

  private handleSelectServer(serverId: string): void {
    const currentId = this.viewModel.selectedServerId;
    this.updateViewModel({
      selectedServerId: currentId === serverId ? null : serverId,
    });
  }

  private async handleToggleConnection(serverId: string, event: any): Promise<void> {
    event?.stopPropagation?.();

    const server = multiServerFederation.getServer(serverId);
    if (!server) return;

    if (server.status === 'connected') {
      await multiServerFederation.disconnectServer(serverId);
    } else {
      await multiServerFederation.connectServer(serverId);
    }
  }

  private async handleConnectAll(): Promise<void> {
    console.log('Connecting to all servers...');
    await multiServerFederation.connectAll();
  }

  private async handleDisconnectAll(): Promise<void> {
    console.log('Disconnecting from all servers...');
    await multiServerFederation.disconnectAll();
  }

  private handleToggleBlueTeam(serverId: string, value: boolean): void {
    multiServerFederation.updatePolicy(serverId, { blueTeamOnly: value });
  }

  private handleToggleAutoShare(serverId: string, value: boolean): void {
    multiServerFederation.updatePolicy(serverId, { autoShare: value });
  }

  private handleEditPolicy(serverId: string): void {
    console.log('Edit policy for server:', serverId);
    this.updateViewModel({ showPolicyDialog: true, selectedServerId: serverId });
  }

  private async handleDeleteServer(serverId: string): Promise<void> {
    console.log('Delete server:', serverId);
    await multiServerFederation.removeServer(serverId);
  }

  private updateViewModel(updates: Partial<FederatedServerScreenViewModel>): void {
    console.log('ViewModel update:', updates);
    this.scheduleRender();
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
    padding: 16,
    paddingTop: 60,
    backgroundColor: '#2A2A2A',
    borderBottomWidth: 2,
    borderBottomColor: '#FFFC00',
  }),

  backButton: new Style<View>({
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  headerContent: new Style<View>({
    flex: 1,
    marginLeft: 8,
  }),

  addButton: new Style<View>({
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  infoBanner: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    marginHorizontal: 16,
    marginTop: 16,
    backgroundColor: 'rgba(75, 175, 255, 0.1)',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: 'rgba(75, 175, 255, 0.3)',
  }),

  infoBannerText: new Style<View>({
    flex: 1,
  }),

  quickActions: new Style<View>({
    flexDirection: 'row',
    gap: 12,
    padding: 16,
  }),

  actionButton: new Style<View>({
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 12,
    backgroundColor: '#2A2A2A',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#3A3A3A',
    cursor: 'pointer',
  }),

  serverList: new Style<View>({
    flex: 1,
    paddingHorizontal: 16,
    overflowY: 'auto',
  }),

  emptyState: new Style<View>({
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 32,
  }),

  serverCard: new Style<View>({
    marginBottom: 12,
    padding: 16,
    backgroundColor: '#2A2A2A',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#3A3A3A',
    cursor: 'pointer',
  }),

  serverCardActive: new Style<View>({
    marginBottom: 12,
    padding: 16,
    backgroundColor: '#2A2A2A',
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#FFFC00',
    cursor: 'pointer',
  }),

  serverHeader: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  }),

  serverHeaderLeft: new Style<View>({
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  }),

  ledConnected: new Style<View>({
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#4CAF50',
    shadowColor: '#4CAF50',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 4,
  }),

  ledConnecting: new Style<View>({
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#FFA500',
    shadowColor: '#FFA500',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 4,
  }),

  ledError: new Style<View>({
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#FF5252',
    shadowColor: '#FF5252',
    shadowOffset: { width: 0, height: 0 },
    shadowOpacity: 0.8,
    shadowRadius: 4,
  }),

  ledDisconnected: new Style<View>({
    width: 12,
    height: 12,
    borderRadius: 6,
    backgroundColor: '#666666',
    borderWidth: 1,
    borderColor: '#999999',
  }),

  serverInfo: new Style<View>({
    flex: 1,
  }),

  connectionButton: new Style<View>({
    paddingVertical: 8,
    paddingHorizontal: 16,
    backgroundColor: 'rgba(255, 252, 0, 0.1)',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: 'rgba(255, 252, 0, 0.3)',
    cursor: 'pointer',
  }),

  serverDetails: new Style<View>({
    marginTop: 16,
    paddingTop: 16,
    borderTopWidth: 1,
    borderTopColor: '#3A3A3A',
  }),

  detailRow: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  }),

  policySection: new Style<View>({
    marginTop: 16,
    padding: 12,
    backgroundColor: 'rgba(255, 252, 0, 0.05)',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: 'rgba(255, 252, 0, 0.2)',
  }),

  policyRow: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 12,
  }),

  toggleOn: new Style<View>({
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: 'rgba(76, 175, 80, 0.2)',
    borderWidth: 2,
    borderColor: '#4CAF50',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  toggleOff: new Style<View>({
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: 'rgba(102, 102, 102, 0.2)',
    borderWidth: 2,
    borderColor: '#666666',
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  typeSection: new Style<View>({
    marginTop: 12,
  }),

  typeChips: new Style<View>({
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  }),

  typeChip: new Style<View>({
    paddingVertical: 4,
    paddingHorizontal: 8,
    backgroundColor: 'rgba(255, 252, 0, 0.1)',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: 'rgba(255, 252, 0, 0.3)',
  }),

  actionRow: new Style<View>({
    flexDirection: 'row',
    gap: 12,
    marginTop: 16,
  }),

  editButton: new Style<View>({
    flex: 1,
    padding: 10,
    backgroundColor: 'rgba(255, 252, 0, 0.1)',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#FFFC00',
    alignItems: 'center',
    cursor: 'pointer',
  }),

  deleteButton: new Style<View>({
    flex: 1,
    padding: 10,
    backgroundColor: 'rgba(255, 82, 82, 0.1)',
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#FF5252',
    alignItems: 'center',
    cursor: 'pointer',
  }),
};
