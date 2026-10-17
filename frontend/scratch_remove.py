import re

files = [
    r'c:\flutter\Howies POS\frontend\lib\services\mock_api_service.dart'
]

for file in files:
    with open(file, 'r+', encoding='utf-8') as f:
        text = f.read()
        text = re.sub(r', deductions: \d+\.\d+', '', text)
        f.seek(0)
        f.write(text)
        f.truncate()
