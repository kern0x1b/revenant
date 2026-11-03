import React from 'react';
import {ScrollView, StyleSheet} from 'react-native';
import {EnrichedMarkdownText} from 'react-native-enriched-markdown';

const MARKDOWN = [
  '# Heading one',
  '',
  'Paragraph with **bold**, _italic_ and a [link](https://example.com).',
  '',
  '- first item',
  '- second item',
  '',
  '```ts',
  'const answer: number = 42;',
  '```',
  '',
  '| name | value |',
  '| --- | --- |',
  '| alpha | 1 |',
  '| beta | 2 |',
  '',
  '$$e^{i\\pi} + 1 = 0$$',
].join('\n');

export default function App() {
  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <EnrichedMarkdownText markdown={MARKDOWN} flavor="github" />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: '#ffffff'},
  content: {paddingTop: 40, paddingHorizontal: 16},
});
