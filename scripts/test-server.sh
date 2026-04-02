#!/bin/bash

# Test the file server upload and serving capabilities
# Usage: bash test-server.sh YOUR_SERVER_IP_OR_DOMAIN

if [ -z "$1" ]; then
  echo "❌ Usage: bash test-server.sh <server-ip-or-domain>"
  echo ""
  echo "Examples:"
  echo "  bash test-server.sh 192.168.1.100"
  echo "  bash test-server.sh files.your-domain.com"
  exit 1
fi

SERVER=$1
PROTOCOL="http"

echo "╔════════════════════════════════════════╗"
echo "║  MIS File Server Test                  ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Server: $SERVER"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test 1: Health check
echo -e "${YELLOW}Test 1: Health Check${NC}"
response=$(curl -s "$PROTOCOL://$SERVER/api/health" 2>/dev/null || echo "FAILED")
if echo "$response" | grep -q "status"; then
  echo -e "${GREEN}✓ Server is responding${NC}"
  echo "  Response: $response" | head -1
else
  echo -e "${RED}✗ Server is not responding${NC}"
  echo "  Make sure:"
  echo "  - Server is running (sudo pm2 list)"
  echo "  - Nginx is running (sudo systemctl status nginx)"
  echo "  - Correct IP/domain"
  exit 1
fi
echo ""

# Test 2: Create test file
echo -e "${YELLOW}Test 2: Creating Test File${NC}"
TEST_FILE="/tmp/test-upload-$(date +%s).txt"
echo "This is a test file for MIS portal uploads" > "$TEST_FILE"
echo "✓ Created: $TEST_FILE"
echo ""

# Test 3: Upload file
echo -e "${YELLOW}Test 3: Uploading File${NC}"
echo "Sending to: $PROTOCOL://$SERVER/api/upload"

UPLOAD_RESPONSE=$(curl -s -X POST \
  -F "file=@$TEST_FILE" \
  "$PROTOCOL://$SERVER/api/upload" 2>/dev/null)

if echo "$UPLOAD_RESPONSE" | grep -q "fileUrl"; then
  echo -e "${GREEN}✓ Upload successful${NC}"
  
  # Extract fileUrl from response
  FILE_URL=$(echo "$UPLOAD_RESPONSE" | grep -o '"fileUrl":"[^"]*' | cut -d'"' -f4)
  FILENAME=$(echo "$UPLOAD_RESPONSE" | grep -o '"filename":"[^"]*' | cut -d'"' -f4)
  
  echo "  Filename: $FILENAME"
  echo "  URL: $FILE_URL"
  echo ""
  
  # Test 4: Download file
  echo -e "${YELLOW}Test 4: Downloading File${NC}"
  DOWNLOAD_URL="$PROTOCOL://$SERVER$FILE_URL"
  echo "Downloading from: $DOWNLOAD_URL"
  
  DOWNLOAD_RESPONSE=$(curl -s -w "\n%{http_code}" "$DOWNLOAD_URL")
  HTTP_CODE=$(echo "$DOWNLOAD_RESPONSE" | tail -1)
  
  if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Download successful (HTTP 200)${NC}"
    echo ""
    
    # Test 5: Verify content
    echo -e "${YELLOW}Test 5: Verifying File Content${NC}"
    CONTENT=$(echo "$DOWNLOAD_RESPONSE" | head -n-1)
    if echo "$CONTENT" | grep -q "This is a test file"; then
      echo -e "${GREEN}✓ Content verified${NC}"
      echo "  Content: $CONTENT"
    else
      echo -e "${RED}✗ Content mismatch${NC}"
    fi
  else
    echo -e "${RED}✗ Download failed (HTTP $HTTP_CODE)${NC}"
    echo "  Make sure Nginx is configured to serve /uploads/"
  fi
else
  echo -e "${RED}✗ Upload failed${NC}"
  echo "  Response: $UPLOAD_RESPONSE"
  echo ""
  echo "  Troubleshooting:"
  echo "  - Check Node.js is running: sudo pm2 list"
  echo "  - Check logs: sudo pm2 logs misapp-files"
  echo "  - Check Nginx proxy: sudo tail -f /var/log/nginx/misapp-error.log"
fi

echo ""

# Test 6: List files
echo -e "${YELLOW}Test 6: Listing Uploaded Files${NC}"
LIST_RESPONSE=$(curl -s "$PROTOCOL://$SERVER/api/files" 2>/dev/null)
if echo "$LIST_RESPONSE" | grep -q "success"; then
  echo -e "${GREEN}✓ File list API working${NC}"
  echo "  Response: $LIST_RESPONSE" | head -c 200
  echo "..."
else
  echo -e "${RED}✗ File list failed${NC}"
fi

echo ""
echo ""
echo "╔════════════════════════════════════════╗"
echo "║  Test Complete                        ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Cleanup: rm $TEST_FILE"
