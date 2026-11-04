import React, {useEffect, useState} from 'react';
import {ScrollView, StyleSheet, Text} from 'react-native';
import * as Notifications from 'expo-notifications';

function describe(value: unknown): string {
  try {
    return JSON.stringify(value);
  } catch (error) {
    return String(value);
  }
}

export default function App() {
  const [lines, setLines] = useState<string[]>([]);

  useEffect(() => {
    const add = (line: string) => {
      console.log('notifications probe: ' + line);
      setLines((previous) => [...previous, line]);
    };
    (async () => {
      try {
        add('getPermissionsAsync ' + describe(await Notifications.getPermissionsAsync()));
      } catch (error) {
        add('getPermissionsAsync failed ' + String(error));
      }
      try {
        add('getDevicePushTokenAsync ' + describe(await Notifications.getDevicePushTokenAsync()));
      } catch (error) {
        add('getDevicePushTokenAsync failed ' + String(error));
      }
    })();
  }, []);

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      {lines.map((line, index) => (
        <Text key={index} style={styles.line}>
          {line}
        </Text>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: '#ffffff'},
  content: {paddingTop: 40, paddingHorizontal: 16},
  line: {fontSize: 14, marginBottom: 8},
});
