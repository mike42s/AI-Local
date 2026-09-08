// Jest test for markdown parser
const markdownParser = require('../lib/markdownParser');

describe('markdownParser', () => {
  it('should throw an error if file is not found', () => {
    expect(() => markdownParser.parseFile('nonexistentfile.md')).toThrow('File not found');
  });

  it('should validate the array JSON correctness', () => {
    // Mock the return value of markdownParser.parseFile
    const mockParsedData = [
      { heading: 1, text: 'Title' },
      { heading: 2, text: 'Subtitle' }
    ];
    const mockReadFile = jest.fn(() => mockParsedData);
    const { parseFile } = markdownParser;
    markdownParser.parseFile = mockReadFile;

    const result = parseFile('testfile.md');
    expect(result).toEqual(mockParsedData);
  });
});
