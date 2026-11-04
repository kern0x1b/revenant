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

const LARGE_COLUMNS = 12;
const LARGE_ROWS = 40;
const LARGE_TABLE = [
  '| ' + Array.from({length: LARGE_COLUMNS}, (_, column) => `column ${column + 1}`).join(' | ') + ' |',
  '| ' + Array.from({length: LARGE_COLUMNS}, () => '---').join(' | ') + ' |',
  ...Array.from({length: LARGE_ROWS}, (_, row) =>
    '| ' + Array.from({length: LARGE_COLUMNS}, (_, column) => `r${row + 1}c${column + 1}`).join(' | ') + ' |',
  ),
].join('\n');

export default function App() {
  return (
    <ScrollView style={styles.screen} contentContainerStyle={styles.content}>
      <EnrichedMarkdownText markdown={MARKDOWN} flavor="github" />
      <EnrichedMarkdownText markdown={LARGE_TABLE} flavor="github" />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: {flex: 1, backgroundColor: '#ffffff'},
  content: {paddingTop: 40, paddingHorizontal: 16},
});
