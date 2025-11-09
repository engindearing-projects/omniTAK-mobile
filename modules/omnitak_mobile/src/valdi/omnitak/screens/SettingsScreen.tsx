import { Component } from 'valdi_core/src/Component';
import { Label, View, Button, ScrollView } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { systemFont } from 'valdi_core/src/SystemFont';

export interface SettingsItem {
  id: string;
  title: string;
  description?: string;
  value?: string;
  type: 'toggle' | 'option' | 'action' | 'section';
  enabled?: boolean;
}

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'SettingsScreenViewModel',
 *   android: 'com.engindearing.omnitak.SettingsScreenViewModel'
 * })
 */
export interface SettingsScreenViewModel {
  settings: SettingsItem[];
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'SettingsScreenContext',
 *   android: 'com.engindearing.omnitak.SettingsScreenContext'
 * })
 */
export interface SettingsScreenContext {
  onSettingChange?: (id: string, value: any) => void;
  onBack?: () => void;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'SettingsScreen',
 *   android: 'com.engindearing.omnitak.SettingsScreen'
 * })
 *
 * ATAK-style settings screen with preferences and configuration options.
 */
export class SettingsScreen extends Component<
  SettingsScreenViewModel,
  SettingsScreenContext
> {
  onCreate(): void {
    console.log('SettingsScreen onCreate');
  }

  onRender(): void {
    const { settings } = this.viewModel;

    <view style={styles.container}>
      {/* Header */}
      <view style={styles.header}>
        <view style={styles.backButton} onClick={this.handleBack.bind(this)}>
          <label value="←" font={systemFont(24)} color="#FFFFFF" />
        </view>
        <label
          value="Settings"
          font={systemFont(20, 'bold')}
          color="#FFFFFF"
        />
        <view width={40} /> {/* Spacer for centering */}
      </view>

      {/* Settings list */}
      <ScrollView style={styles.scrollView}>
        <view style={styles.content}>
          {settings.map((setting) => this.renderSettingItem(setting))}
        </view>
      </ScrollView>
    </view>;
  }

  private renderSettingItem(setting: SettingsItem): void {
    if (setting.type === 'section') {
      <view style={styles.sectionHeader}>
        <label
          value={setting.title}
          font={systemFont(14, 'bold')}
          color="#FFFC00"
        />
      </view>;
      return;
    }

    <view style={styles.settingItem}>
      <view style={styles.settingInfo}>
        <label
          value={setting.title}
          font={systemFont(16)}
          color="#FFFFFF"
        />
        {setting.description && (
          <label
            value={setting.description}
            font={systemFont(12)}
            color="#999999"
            marginTop={4}
          />
        )}
      </view>

      {setting.type === 'toggle' && (
        <view
          style={setting.enabled ? styles.toggleOn : styles.toggleOff}
          onClick={() => this.handleToggle(setting.id, !setting.enabled)}
        >
          <view
            style={setting.enabled ? styles.toggleKnobOn : styles.toggleKnobOff}
          />
        </view>
      )}

      {setting.type === 'option' && (
        <view style={styles.optionValue}>
          <label
            value={setting.value || 'None'}
            font={systemFont(14)}
            color="#CCCCCC"
            marginRight={8}
          />
          <label value="›" font={systemFont(20)} color="#666666" />
        </view>
      )}

      {setting.type === 'action' && (
        <view style={styles.actionButton}>
          <label value="›" font={systemFont(20)} color="#666666" />
        </view>
      )}
    </view>;
  }

  private handleToggle(id: string, value: boolean): void {
    console.log('Toggle setting:', id, value);
    if (this.context.onSettingChange) {
      this.context.onSettingChange(id, value);
    }
  }

  private handleBack(): void {
    console.log('Back from settings');
    if (this.context.onBack) {
      this.context.onBack();
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
    paddingTop: 60, // Account for status bar
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

  scrollView: new Style<ScrollView>({
    flex: 1,
  }),

  content: new Style<View>({
    padding: 16,
  }),

  sectionHeader: new Style<View>({
    paddingVertical: 12,
    paddingHorizontal: 4,
    marginTop: 16,
  }),

  settingItem: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 16,
    backgroundColor: '#2A2A2A',
    borderRadius: 8,
    marginBottom: 8,
  }),

  settingInfo: new Style<View>({
    flex: 1,
    marginRight: 16,
  }),

  toggleOff: new Style<View>({
    width: 50,
    height: 30,
    borderRadius: 15,
    backgroundColor: '#666666',
    padding: 2,
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  toggleOn: new Style<View>({
    width: 50,
    height: 30,
    borderRadius: 15,
    backgroundColor: '#4CAF50',
    padding: 2,
    justifyContent: 'center',
    alignItems: 'flex-end',
    cursor: 'pointer',
  }),

  toggleKnobOff: new Style<View>({
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: '#FFFFFF',
  }),

  toggleKnobOn: new Style<View>({
    width: 26,
    height: 26,
    borderRadius: 13,
    backgroundColor: '#FFFFFF',
  }),

  optionValue: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
  }),

  actionButton: new Style<View>({
    padding: 4,
  }),
};
