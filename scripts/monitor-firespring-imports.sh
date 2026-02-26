#!/bin/bash
# Monitor Firespring import progress

while true; do
  clear
  echo "╔════════════════════════════════════════════════════════════╗"
  echo "║          FIRESPRING IMPORT STATUS                          ║"
  echo "╚════════════════════════════════════════════════════════════╝"
  echo ""
  date
  echo ""

  echo "Actions (28,917):      $(tail -1 /tmp/firespring-actions-import.log 2>/dev/null | grep -o 'Batch [0-9]*/[0-9]*' || echo 'Not started')"
  echo "Visitors (13,779):     $(tail -1 /tmp/firespring-visitors-import.log 2>/dev/null | grep -o 'Batch [0-9]*/[0-9]*' || echo 'Not started')"
  echo "Jobs (1,915):          $(tail -1 /tmp/firespring-jobs-import.log 2>/dev/null | grep -o 'Batch [0-9]*/[0-9]*' || echo 'Not started')"
  echo "Sources (1,730):       $(tail -1 /tmp/firespring-sources-import.log 2>/dev/null | grep -o 'Batch [0-9]*/[0-9]*' || echo 'Not started')"
  echo "Segments (1,728):      COMPLETE - 1,684/1,728 imported"
  echo ""

  RUNNING=$(ps aux | grep "import-dynamodb" | grep -v grep | wc -l)
  echo "Active imports: $RUNNING"

  if [ "$RUNNING" -eq 0 ]; then
    echo ""
    echo "All imports complete!"
    break
  fi

  sleep 5
done

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          FINAL SUPABASE COUNTS                             ║"
echo "╚════════════════════════════════════════════════════════════╝"
tail -3 /tmp/firespring-actions-import.log
tail -3 /tmp/firespring-visitors-import.log
tail -3 /tmp/firespring-jobs-import.log
tail -3 /tmp/firespring-sources-import.log
