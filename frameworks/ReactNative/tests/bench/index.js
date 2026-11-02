import React, {useEffect, useRef, useState} from 'react';
import {Animated, AppRegistry, FlatList, Pressable, Text, View} from 'react-native';

const ROWS = Array.from({length: 500}, (_, index) => ({
  id: String(index),
  label: 'row ' + index + ' ' + ((index * 7919) % 1000),
}));

function now() {
  return Date.now();
}

async function promiseChain(steps) {
  let total = 0;
  for (let index = 0; index < steps; index++) {
    total += await Promise.resolve(index);
  }
  return total;
}

function jsonRound() {
  const items = [];
  for (let index = 0; index < 5000; index++) {
    items.push({index, name: 'item ' + index, tags: ['a', 'b'], value: index * 1.5});
  }
  return JSON.parse(JSON.stringify(items)).length;
}

function Row({label}) {
  return (
    <View style={{height: 40, justifyContent: 'center', paddingLeft: 12, borderBottomWidth: 1, borderColor: '#ddd'}}>
      <Text>{label}</Text>
    </View>
  );
}

function Bench() {
  const [count, setCount] = useState(0);
  const sway = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    const started = now();
    console.log('bench mounted ' + started);
    promiseChain(2000).then(total => {
      console.log('bench promise ' + total + ' ms ' + (now() - started));
    });
    const jsonStarted = now();
    const length = jsonRound();
    console.log('bench json ' + length + ' ms ' + (now() - jsonStarted));
    Animated.loop(
      Animated.sequence([
        Animated.timing(sway, {toValue: 1, duration: 800, useNativeDriver: false}),
        Animated.timing(sway, {toValue: 0, duration: 800, useNativeDriver: false}),
      ]),
    ).start();
  }, [sway]);

  useEffect(() => {
    let frames = 0;
    let windowStart = now();
    let handle;
    const tick = () => {
      frames++;
      const time = now();
      if (time - windowStart >= 1000) {
        console.log('bench fps ' + frames + ' ' + time);
        frames = 0;
        windowStart = time;
      }
      handle = requestAnimationFrame(tick);
    };
    handle = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(handle);
  }, []);

  useEffect(() => {
    if (count > 0) {
      console.log('bench commit ' + count + ' ' + now());
    }
  }, [count]);

  const width = sway.interpolate({inputRange: [0, 1], outputRange: [20, 280]});

  return (
    <View style={{flex: 1, paddingTop: 60, backgroundColor: '#fff'}}>
      <Pressable
        testID="counter"
        onPress={() => setCount(value => value + 1)}
        style={{position: 'absolute', top: 60, left: 20, width: 200, height: 60, borderRadius: 8, backgroundColor: '#2563eb', justifyContent: 'center', alignItems: 'center'}}>
        <Text style={{color: '#fff', fontSize: 18}}>count {count}</Text>
      </Pressable>
      <Animated.View style={{position: 'absolute', top: 140, left: 0, width, height: 16, backgroundColor: '#16a34a'}} />
      <View style={{position: 'absolute', top: 180, left: 0, right: 0, bottom: 0}}>
        <FlatList data={ROWS} keyExtractor={item => item.id} renderItem={({item}) => <Row label={item.label} />} initialNumToRender={20} />
      </View>
    </View>
  );
}

AppRegistry.registerComponent('bench', () => Bench);
