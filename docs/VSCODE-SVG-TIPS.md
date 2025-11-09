# VS Code에서 SVG 파일 편집하는 방법

## 🎯 문제: SVG 파일이 그림으로만 보임

VS Code는 기본적으로 SVG 파일을 **이미지 뷰어**로 열기 때문에 코드를 볼 수 없습니다.

## ✅ 해결 방법

### Option 1: 우클릭 메뉴 (가장 빠름) ⚡

```
1. SVG 파일 우클릭
2. "Open With..." 선택
3. "Text Editor" 선택
4. 이제 XML 코드로 보임!
```

### Option 2: Command Palette

```
1. SVG 파일 열기
2. Cmd+Shift+P (Mac) 또는 Ctrl+Shift+P (Windows)
3. "Reopen Editor With..." 입력
4. "Text Editor" 선택
```

### Option 3: settings.json 설정 (영구적) 🔧

VS Code 설정 파일에 추가:

```json
{
  "workbench.editorAssociations": {
    "*.svg": "default"
  }
}
```

**적용 방법**:
1. Command Palette 열기 (`Cmd+Shift+P`)
2. "Preferences: Open User Settings (JSON)" 입력
3. 위 설정 추가
4. VS Code 재시작

### Option 4: 파일 확장자 임시 변경

```bash
# 임시로 .txt로 변경
mv network-architecture-diagram.svg network-architecture-diagram.svg.txt

# 편집 완료 후 다시 .svg로
mv network-architecture-diagram.svg.txt network-architecture-diagram.svg
```

## 🎨 추천 VS Code 확장 프로그램

### 1. SVG Viewer
```
설치: code --install-extension cssho.vscode-svgviewer
기능: SVG 미리보기 + 코드 동시 보기
```

### 2. SVG (by jock)
```
설치: code --install-extension jock.svg
기능: SVG 문법 하이라이팅, 자동완성
```

### 3. SVG Preview
```
설치: code --install-extension SimonSiefke.svg-preview
기능: 실시간 SVG 미리보기 패널
```

## 💡 효율적인 SVG 편집 워크플로우

### 1. 분할 화면 사용

```
1. SVG 파일을 Text Editor로 열기
2. Cmd+\ (Mac) 또는 Ctrl+\ (Windows) - 화면 분할
3. 오른쪽에 미리보기 열기 (우클릭 → "Open Preview")
4. 왼쪽에서 코드 편집, 오른쪽에서 실시간 확인
```

### 2. 특정 요소 빠르게 찾기

```
1. Cmd+F (Mac) 또는 Ctrl+F (Windows)
2. 검색어 입력:
   - "ECS Tasks" → ECS 섹션 찾기
   - id="igw" → Internet Gateway 찾기
   - fill="#ff9800" → 주황색 요소 모두 찾기
```

### 3. 여러 곳 동시 수정

```
1. 수정할 텍스트 선택
2. Cmd+D (Mac) 또는 Ctrl+D (Windows) - 다음 동일 항목 선택
3. 모두 선택될 때까지 반복
4. 한 번에 수정
```

**예시**: 모든 "Arial" 폰트를 "Helvetica"로 변경
```
1. "Arial" 선택
2. Cmd+Shift+L (모두 선택)
3. "Helvetica" 입력
```

## 🔍 SVG 코드 읽는 방법

### 기본 구조
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 1000">
  <!-- 캔버스 크기: 1400x1000px -->
  
  <!-- 그룹 (여러 요소를 묶음) -->
  <g id="igw">
    <!-- 사각형 -->
    <rect x="630" y="160" width="140" height="60" 
          fill="#ff9800" stroke="#e65100" stroke-width="2" rx="5"/>
    
    <!-- 텍스트 -->
    <text x="700" y="185" text-anchor="middle" fill="white">
      Internet Gateway
    </text>
  </g>
</svg>
```

### 주요 SVG 태그

| 태그 | 의미 | 주요 속성 |
|------|------|----------|
| `<rect>` | 사각형 | x, y, width, height, fill, stroke |
| `<circle>` | 원 | cx, cy, r, fill |
| `<ellipse>` | 타원 | cx, cy, rx, ry, fill |
| `<line>` | 선 | x1, y1, x2, y2, stroke |
| `<text>` | 텍스트 | x, y, fill, font-size |
| `<g>` | 그룹 | id, transform |

### 색상 속성

```xml
fill="#ff9800"          <!-- 채우기 색 -->
stroke="#e65100"        <!-- 테두리 색 -->
stroke-width="2"        <!-- 테두리 두께 -->
opacity="0.5"           <!-- 투명도 -->
```

### 위치 속성

```xml
x="630"                 <!-- 수평 위치 (왼쪽에서) -->
y="160"                 <!-- 수직 위치 (위에서) -->
width="140"             <!-- 너비 -->
height="60"             <!-- 높이 -->
```

### 텍스트 정렬

```xml
text-anchor="start"     <!-- 왼쪽 정렬 -->
text-anchor="middle"    <!-- 중앙 정렬 (권장) -->
text-anchor="end"       <!-- 오른쪽 정렬 -->
```

## 🎨 색상 빠르게 변경하기

### 1. 색상 선택기 사용

VS Code에는 색상 코드 위에 커서를 올리면 색상 선택기가 나타납니다:

```xml
<rect fill="#ff9800"/>
           ↑ 여기 클릭!
```

### 2. 색상 검색/치환

```
1. Cmd+H (Mac) 또는 Ctrl+H (Windows) - 찾기/바꾸기
2. 찾기: #ff9800
3. 바꾸기: #4caf50
4. "Replace All" 클릭
```

## 📐 좌표 계산 팁

### 요소를 오른쪽으로 50px 이동

```xml
<!-- Before -->
<rect x="630" .../>

<!-- After -->
<rect x="680" .../>  <!-- 630 + 50 = 680 -->
```

### 요소를 아래로 30px 이동

```xml
<!-- Before -->
<rect y="160" .../>

<!-- After -->
<rect y="190" .../>  <!-- 160 + 30 = 190 -->
```

### 중앙 정렬된 텍스트도 같이 이동

```xml
<!-- 박스가 오른쪽으로 50px 이동하면 -->
<rect x="630" width="140" .../>  → <rect x="680" width="140" .../>

<!-- 중앙 텍스트도 같은 거리만큼 이동 -->
<text x="700" .../>  → <text x="750" .../>
<!-- 계산: 700 + 50 = 750 -->
```

## 🐛 트러블슈팅

### 문제 1: 수정 후 이미지가 안 보임

**원인**: XML 문법 오류

**해결**:
```bash
# Git으로 이전 버전 복원
git restore docs/network-architecture-diagram.svg

# 또는 백업에서 복원
cp docs/network-architecture-diagram.svg.backup docs/network-architecture-diagram.svg
```

**예방**: 수정 전 백업
```bash
cp docs/network-architecture-diagram.svg docs/network-architecture-diagram.svg.backup
```

### 문제 2: 태그가 닫히지 않음

**오류**:
```xml
<rect x="100" y="100" width="50" height="50">
<!-- ❌ 닫는 태그가 없음! -->
```

**해결**:
```xml
<!-- Option 1: 자체 닫기 -->
<rect x="100" y="100" width="50" height="50"/>

<!-- Option 2: 명시적으로 닫기 -->
<rect x="100" y="100" width="50" height="50"></rect>
```

### 문제 3: 특수문자 표시 안됨

**오류**:
```xml
<text>Customers & Vets</text>
<!-- ❌ & 기호가 XML 예약어 -->
```

**해결**:
```xml
<text>Customers &amp; Vets</text>
<!-- ✅ &를 &amp;로 변경 -->
```

주요 이스케이프:
- `&` → `&amp;`
- `<` → `&lt;`
- `>` → `&gt;`
- `"` → `&quot;`
- `'` → `&apos;`

### 문제 4: 요소가 잘림

**원인**: viewBox 범위를 벗어남

```xml
<svg viewBox="0 0 1400 1000">
  <!-- 1400x1000 영역만 보임 -->
  <rect x="1500" y="100" .../>
  <!-- ❌ x=1500은 화면 밖! -->
</svg>
```

**해결**:
1. 요소를 viewBox 안으로 이동
2. 또는 viewBox 크기 증가

## 💡 유용한 단축키

| 기능 | Mac | Windows |
|------|-----|---------|
| 찾기 | `Cmd+F` | `Ctrl+F` |
| 찾기/바꾸기 | `Cmd+H` | `Ctrl+H` |
| 다중 커서 | `Option+Click` | `Alt+Click` |
| 라인 복사 | `Shift+Option+↓` | `Shift+Alt+↓` |
| 라인 이동 | `Option+↑/↓` | `Alt+↑/↓` |
| 주석 토글 | `Cmd+/` | `Ctrl+/` |

## 📚 참고 자료

- [SVG Tutorial - MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial)
- [VS Code Tips](https://code.visualstudio.com/docs/getstarted/tips-and-tricks)
- [SVG 색상 도구](https://www.w3schools.com/colors/colors_picker.asp)

## 🎯 실전 예제: ECS Tasks 수정

### Before (문제)
```xml
<rect x="180" y="505" width="140" height="120" .../>
<!-- Customers, Vets만 있음 -->
```

### After (수정)
```xml
<rect x="180" y="505" width="140" height="155" .../>
<!-- height를 155로 증가 -->

<!-- 4개 서비스 모두 추가 -->
<rect x="195" y="535" width="110" height="25" .../>
<text>Customers</text>

<rect x="195" y="565" width="110" height="25" .../>
<text>Vets</text>

<rect x="195" y="595" width="110" height="25" .../>
<text>Visits</text>

<rect x="195" y="625" width="110" height="25" .../>
<text>Admin</text>
```

## ✅ 체크리스트

수정하기 전에:
- [ ] 백업 생성: `cp file.svg file.svg.backup`
- [ ] Git 커밋: 현재 상태 저장
- [ ] 미리보기 준비: 분할 화면 설정

수정 중에:
- [ ] 자주 저장 (Cmd+S)
- [ ] 미리보기 확인
- [ ] 문법 오류 체크

수정 후에:
- [ ] 브라우저에서 확인
- [ ] Git diff 확인
- [ ] 커밋 및 푸시

---

**Tip**: 수정이 어렵거나 복잡하면 AI에게 요청하세요! 
"NAT Gateway를 왼쪽으로 이동해줘" 같은 자연어 요청도 가능합니다. 🤖
