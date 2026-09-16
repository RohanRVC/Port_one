package ingest

import "bufio"

// stripBOM discards a leading UTF-8 byte-order-mark from br, if present.
// Both source files were saved with one; encoding/csv doesn't strip it and
// would otherwise corrupt the first header cell's name.
func stripBOM(br *bufio.Reader) {
	bom, err := br.Peek(3)
	if err == nil && len(bom) == 3 && bom[0] == 0xEF && bom[1] == 0xBB && bom[2] == 0xBF {
		br.Discard(3)
	}
}
