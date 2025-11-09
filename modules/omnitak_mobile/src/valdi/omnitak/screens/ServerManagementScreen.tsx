import { Component } from 'valdi_core/src/Component';
import { Label, View, Button, ScrollView, TextInput } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { systemFont } from 'valdi_core/src/SystemFont';

export interface ServerConnection {
  id: string;
  name: string;
  host: string;
  port: number;
  protocol: 'tcp' | 'ssl' | 'udp';
  status: 'connected' | 'disconnected' | 'error' | 'connecting';
  lastConnected?: string;
}

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'ServerManagementViewModel',
 *   android: 'com.engindearing.omnitak.ServerManagementViewModel'
 * })
 */
export interface ServerManagementViewModel {
  servers: ServerConnection[];
  showAddDialog: boolean;
  editingServer?: ServerConnection;
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'ServerManagementContext',
 *   android: 'com.engindearing.omnitak.ServerManagementContext'
 * })
 */
export interface ServerManagementContext {
  onBack?: () => void;
  onConnect?: (serverId: string) => void;
  onDisconnect?: (serverId: string) => void;
  onAddServer?: (server: Partial<ServerConnection>) => void;
  onEditServer?: (serverId: string) => void;
  onDeleteServer?: (serverId: string) => void;
  onShowAddDialog?: () => void;
  onHideAddDialog?: () => void;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'ServerManagementScreen',
 *   android: 'com.engindearing.omnitak.ServerManagementScreen'
 * })
 *
 * ATAK-style server/network connection management screen.
 * Allows users to view, add, edit, and connect to TAK servers.
 */
export class ServerManagementScreen extends Component<
  ServerManagementViewModel,
  ServerManagementContext
> {
  onCreate(): void {
    console.log('ServerManagementScreen onCreate');
  }

  onRender(): void {
    const { servers, showAddDialog } = this.viewModel;

    <view style={styles.container}>
      {/* Header */}
      <view style={styles.header}>
        <view style={styles.backButton} onClick={this.handleBack.bind(this)}>
          <label value="←" font={systemFont(24)} color="#FFFFFF" />
        </view>
        <label
          value="Network Connections"
          font={systemFont(20, 'bold')}
          color="#FFFFFF"
        />
        <view
          style={styles.addButton}
          onClick={this.handleShowAddDialog.bind(this)}
        >
          <label value="+" font={systemFont(28)} color="#FFFC00" />
        </view>
      </view>

      {/* Server list */}
      <ScrollView style={styles.scrollView}>
        <view style={styles.content}>
          {servers.length === 0 ? (
            <view style={styles.emptyState}>
              <label
                value="No servers configured"
                font={systemFont(16)}
                color="#999999"
                marginBottom={8}
              />
              <label
                value="Tap + to add a TAK server"
                font={systemFont(14)}
                color="#666666"
              />
            </view>
          ) : (
            servers.map((server) => this.renderServerItem(server))
          )}
        </view>
      </ScrollView>

      {/* Add/Edit server dialog */}
      {showAddDialog && this.renderAddServerDialog()}
    </view>;
  }

  private renderServerItem(server: ServerConnection): void {
    const statusColor = this.getStatusColor(server.status);
    const statusText = this.getStatusText(server.status);

    <view style={styles.serverItem}>
      {/* Server info */}
      <view style={styles.serverInfo}>
        <view style={styles.serverHeader}>
          <label
            value={server.name}
            font={systemFont(16, 'bold')}
            color="#FFFFFF"
          />
          <view style={styles.statusBadge}>
            <view
              width={8}
              height={8}
              borderRadius={4}
              backgroundColor={statusColor}
              marginRight={6}
            />
            <label
              value={statusText}
              font={systemFont(11)}
              color={statusColor}
            />
          </view>
        </view>

        <label
          value={`${server.host}:${server.port}`}
          font={systemFont(14)}
          color="#CCCCCC"
          marginTop={4}
        />

        <label
          value={`Protocol: ${server.protocol.toUpperCase()}`}
          font={systemFont(12)}
          color="#999999"
          marginTop={2}
        />

        {server.lastConnected && (
          <label
            value={`Last connected: ${server.lastConnected}`}
            font={systemFont(11)}
            color="#666666"
            marginTop={2}
          />
        )}
      </view>

      {/* Action buttons */}
      <view style={styles.serverActions}>
        {server.status === 'connected' ? (
          <view
            style={styles.actionButton}
            onClick={() => this.handleDisconnect(server.id)}
          >
            <label
              value="Disconnect"
              font={systemFont(12, 'bold')}
              color="#FF5252"
            />
          </view>
        ) : (
          <view
            style={styles.actionButton}
            onClick={() => this.handleConnect(server.id)}
          >
            <label
              value="Connect"
              font={systemFont(12, 'bold')}
              color="#4CAF50"
            />
          </view>
        )}

        <view
          style={styles.iconButton}
          onClick={() => this.handleEdit(server.id)}
        >
          <label value="✏️" font={systemFont(16)} />
        </view>

        <view
          style={styles.iconButton}
          onClick={() => this.handleDelete(server.id)}
        >
          <label value="🗑️" font={systemFont(16)} />
        </view>
      </view>
    </view>;
  }

  private renderAddServerDialog(): void {
    <view style={styles.dialogOverlay}>
      <view style={styles.dialog}>
        <view style={styles.dialogHeader}>
          <label
            value="Add TAK Server"
            font={systemFont(18, 'bold')}
            color="#FFFFFF"
          />
          <view
            style={styles.closeButton}
            onClick={this.handleHideAddDialog.bind(this)}
          >
            <label value="✕" font={systemFont(20)} color="#FFFFFF" />
          </view>
        </view>

        <view style={styles.dialogContent}>
          <label
            value="Server Name"
            font={systemFont(12)}
            color="#CCCCCC"
            marginBottom={4}
          />
          <TextInput
            style={styles.input}
            placeholder="e.g., TAK Server 1"
            placeholderColor="#666666"
          />

          <label
            value="Host / IP Address"
            font={systemFont(12)}
            color="#CCCCCC"
            marginTop={16}
            marginBottom={4}
          />
          <TextInput
            style={styles.input}
            placeholder="e.g., 192.168.1.100"
            placeholderColor="#666666"
          />

          <label
            value="Port"
            font={systemFont(12)}
            color="#CCCCCC"
            marginTop={16}
            marginBottom={4}
          />
          <TextInput
            style={styles.input}
            placeholder="e.g., 8087"
            placeholderColor="#666666"
            keyboardType="number-pad"
          />

          <label
            value="Protocol"
            font={systemFont(12)}
            color="#CCCCCC"
            marginTop={16}
            marginBottom={8}
          />
          <view style={styles.protocolOptions}>
            <view style={styles.protocolOption}>
              <label value="TCP" font={systemFont(14)} color="#FFFFFF" />
            </view>
            <view style={styles.protocolOption}>
              <label value="SSL" font={systemFont(14)} color="#FFFFFF" />
            </view>
            <view style={styles.protocolOption}>
              <label value="UDP" font={systemFont(14)} color="#FFFFFF" />
            </view>
          </view>
        </view>

        <view style={styles.dialogActions}>
          <view
            style={styles.dialogButton}
            onClick={this.handleHideAddDialog.bind(this)}
          >
            <label
              value="Cancel"
              font={systemFont(14)}
              color="#999999"
            />
          </view>
          <view
            style={styles.dialogButtonPrimary}
            onClick={this.handleAddServer.bind(this)}
          >
            <label
              value="Add Server"
              font={systemFont(14, 'bold')}
              color="#1E1E1E"
            />
          </view>
        </view>
      </view>
    </view>;
  }

  private getStatusColor(status: string): string {
    switch (status) {
      case 'connected':
        return '#4CAF50';
      case 'connecting':
        return '#FFA500';
      case 'error':
        return '#FF5252';
      default:
        return '#666666';
    }
  }

  private getStatusText(status: string): string {
    switch (status) {
      case 'connected':
        return 'Connected';
      case 'connecting':
        return 'Connecting...';
      case 'error':
        return 'Error';
      default:
        return 'Disconnected';
    }
  }

  private handleBack(): void {
    if (this.context.onBack) {
      this.context.onBack();
    }
  }

  private handleConnect(serverId: string): void {
    if (this.context.onConnect) {
      this.context.onConnect(serverId);
    }
  }

  private handleDisconnect(serverId: string): void {
    if (this.context.onDisconnect) {
      this.context.onDisconnect(serverId);
    }
  }

  private handleEdit(serverId: string): void {
    if (this.context.onEditServer) {
      this.context.onEditServer(serverId);
    }
  }

  private handleDelete(serverId: string): void {
    if (this.context.onDeleteServer) {
      this.context.onDeleteServer(serverId);
    }
  }

  private handleShowAddDialog(): void {
    if (this.context.onShowAddDialog) {
      this.context.onShowAddDialog();
    }
  }

  private handleHideAddDialog(): void {
    if (this.context.onHideAddDialog) {
      this.context.onHideAddDialog();
    }
  }

  private handleAddServer(): void {
    // TODO: Collect form data and call onAddServer
    if (this.context.onAddServer) {
      this.context.onAddServer({
        name: 'New Server',
        host: '192.168.1.100',
        port: 8087,
        protocol: 'tcp',
        status: 'disconnected',
      });
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

  addButton: new Style<View>({
    width: 40,
    height: 40,
    alignItems: 'center',
    justifyContent: 'center',
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

  serverItem: new Style<View>({
    backgroundColor: '#2A2A2A',
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
  }),

  serverInfo: new Style<View>({
    marginBottom: 12,
  }),

  serverHeader: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  }),

  statusBadge: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1E1E1E',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
  }),

  serverActions: new Style<View>({
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

  iconButton: new Style<View>({
    width: 36,
    height: 36,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#3A3A3A',
    borderRadius: 4,
    cursor: 'pointer',
  }),

  dialogOverlay: new Style<View>({
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    alignItems: 'center',
    justifyContent: 'center',
    zIndex: 2000,
  }),

  dialog: new Style<View>({
    width: '90%',
    maxWidth: 500,
    backgroundColor: '#2A2A2A',
    borderRadius: 12,
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
  }),

  dialogHeader: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#3A3A3A',
  }),

  closeButton: new Style<View>({
    width: 32,
    height: 32,
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  dialogContent: new Style<View>({
    padding: 20,
  }),

  input: new Style<TextInput>({
    backgroundColor: '#1E1E1E',
    color: '#FFFFFF',
    padding: 12,
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#3A3A3A',
    fontSize: 14,
  }),

  protocolOptions: new Style<View>({
    flexDirection: 'row',
    gap: 8,
  }),

  protocolOption: new Style<View>({
    flex: 1,
    padding: 12,
    backgroundColor: '#1E1E1E',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#3A3A3A',
    alignItems: 'center',
    cursor: 'pointer',
  }),

  dialogActions: new Style<View>({
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 12,
    padding: 20,
    borderTopWidth: 1,
    borderTopColor: '#3A3A3A',
  }),

  dialogButton: new Style<View>({
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 4,
    cursor: 'pointer',
  }),

  dialogButtonPrimary: new Style<View>({
    paddingHorizontal: 20,
    paddingVertical: 10,
    backgroundColor: '#FFFC00',
    borderRadius: 4,
    cursor: 'pointer',
  }),
};
