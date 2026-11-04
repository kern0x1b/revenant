import React, {useEffect} from 'react';
import {ScrollView, StyleSheet, Text, View} from 'react-native';
import Animated, {
  FadeIn,
  runOnJS,
  runOnUI,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';

function report(line) {
  console.log('reanimated probe: ' + line);
}

export default function App() {
  const offset = useSharedValue(0);
  const opacity = useSharedValue(0);

  useEffect(() => {
    runOnUI(() => {
      'worklet';
      console.log('worklet ran on UI');
      runOnJS(report)('worklet callback on JS');
      offset.value = 42;
    })();
    opacity.value = withTiming(1, {duration: 300}, finished => {
      'worklet';
      runOnJS(report)('withTiming finished ' + finished);
    });
  }, [offset, opacity]);

  const movedStyle = useAnimatedStyle(() => ({transform: [{translateX: offset.value}]}));
  const fadedStyle = useAnimatedStyle(() => ({opacity: opacity.value}));

  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <Text style={styles.label}>static (no animation)</Text>
      <View style={styles.box}>
        <Text style={styles.text}>STATIC TEXT</Text>
      </View>

      <Text style={styles.label}>useAnimatedStyle moved by 42 on UI</Text>
      <Animated.View style={[styles.box, movedStyle]}>
        <Text style={styles.text}>MOVED TEXT</Text>
      </Animated.View>

      <Text style={styles.label}>withTiming opacity 0 to 1 over 300 ms</Text>
      <Animated.View style={[styles.box, fadedStyle]}>
        <Text style={styles.text}>TWEEN TEXT</Text>
      </Animated.View>

      <Text style={styles.label}>entering FadeIn</Text>
      <Animated.View entering={FadeIn.duration(300)} style={styles.box}>
        <Text style={styles.text}>ENTERING TEXT</Text>
      </Animated.View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: '#ffffff'},
  content: {paddingTop: 60, paddingHorizontal: 16},
  label: {fontSize: 12, color: '#666666', marginTop: 16},
  box: {marginTop: 6, padding: 10, borderWidth: 1, borderColor: '#999999'},
  text: {fontSize: 20, color: '#000000'},
});
