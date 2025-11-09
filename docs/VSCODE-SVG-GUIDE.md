# VS Code에서 SVG 코드 보는 방법

## 🔴 문제 상황

VS Code에서 `.svg` 파일을 열면 **그림(미리보기)**만 보이고 **코드(XML)**가 안 보입니다!

```
network-architecture-diagram.svg 클릭
         ↓
   [그림만 보임] 😢
         ↓
   코드를 수정하고 싶은데...
```

## ✅ 해결 방법

### 방법 1: 우클릭 메뉴 (가장 쉬움!) ⭐

#### 단계별:

1. **파일 탐색기에서 SVG 파일 찾기**
   ```
   docs/network-architecture-diagram.svg
   ```

2. **우클릭**
   ```
   [우클릭]
      ↓
   📋 Open With...
   📋 Reveal in Finder
   📋 Copy Path
   ...
   ```

3. **"Open With..." 선택**

4. **"Text Editor" 선택**
   ```
   ✓ Text Editor          ← 이것 선택!
   ○ SVG Preview
   ○ Live Preview
   ...
   ```

5. **✅ 완료! 이제 XML 코드가 보입니다**

#### 실제 보이는 코드:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 1000">
  <!-- Title -->
  <text x="700" y="30">PetClinic AWS Network Architecture</text>
  
  <!-- Internet Gateway -->
  <g id="igw">
    <rect x="630" y="160" width="140" height="60" fill="#ff9800"/>
    <text x="700" y="185">Internet Gateway</text>
  </g>
  ...
</svg>
```

---

### 방법 2: 커맨드 팔레트 (단축키)

#### macOS:
```
1. SVG 파일 선택
2. Cmd + Shift + P
3. "Reopen Editor With" 타이핑
4. "Text Editor" 선택
```

#### Windows/Linux:
```
1. SVG 파일 선택
2. Ctrl + Shift + P
3. "Reopen Editor With" 타이핑
4. "Text Editor" 선택
```

#### 스크린샷:
```
┌─────────────────────────────────────────┐
│ > Reopen Editor With                    │ ← 타이핑
├─────────────────────────────────────────┤
│ ✓ Text Editor                           │ ← 선택!
│   SVG Preview                           │
│   Live Preview                          │
└─────────────────────────────────────────┘
```

---

### 방법 3: 기본 설정 변경 (항상 코드로 열기)

이 방법을 사용하면 **앞으로 모든 SVG를 자동으로 코드로 엽니다**.

#### 단계별:

1. **VS Code 설정 열기**
   ```
   macOS: Cmd + ,
   Windows/Linux: Ctrl + ,
   ```

2. **검색창에 "svg" 입력**

3. **"Workbench: Editor Associations" 찾기**

4. **"Edit in settings.json" 클릭**

5. **다음 코드 추가**:
   ```json
   {
     "workbench.editorAssociations": {
       "*.svg": "default"
     }
   }
   ```

6. **저장 (Cmd/Ctrl + S)**

7. **✅ 완료! 이제 SVG는 항상 코드로 열립니다**

#### 전체 settings.json 예시:
```json
{
  "editor.fontSize": 14,
  "editor.tabSize": 2,
  "workbench.editorAssociations": {
    "*.svg": "default"  // ← 이 줄 추가!
  }
}
```

---

### 방법 4: 파일명 변경 (임시 방법)

빠르게 한 번만 보고 싶을 때:

```bash
# 원래 파일명
network-architecture-diagram.svg

# 임시 변경
network-architecture-diagram.svg.xml

# VS Code에서 열기
# → XML로 자동 인식되어 코드로 보임!

# 다시 원래대로
network-architecture-diagram.xml → .svg
```

---

### 방법 5: 터미널에서 직접 열기

```bash
# 코드 에디터로 강제 열기
code -r docs/network-architecture-diagram.svg

# 또는 cat으로 출력
cat docs/network-architecture-diagram.svg

# 또는 less로 읽기
less docs/network-architecture-diagram.svg
```

---

## 🎨 코드 vs 미리보기 전환

### 코드 → 미리보기로 전환:

```
방법 1: 우클릭 → "Open With" → "SVG Preview"
방법 2: Cmd/Ctrl + Shift + P → "Reopen With" → "SVG Preview"
```

### 미리보기 → 코드로 전환:

```
방법 1: 우클릭 → "Open With" → "Text Editor"
방법 2: Cmd/Ctrl + Shift + P → "Reopen With" → "Text Editor"
```

### 양쪽 동시에 보기 (Split View):

```
1. SVG 파일을 Text Editor로 열기
2. 우클릭 → "Open Preview to the Side"
3. 양쪽에 코드와 미리보기가 동시에 보임!

┌──────────────┬──────────────┐
│ [코드]       │ [미리보기]   │
│              │              │
│ <svg>        │   ┌────┐    │
│   <rect/>    │   │    │    │
│ </svg>       │   └────┘    │
└──────────────┴──────────────┘
```

---

## 🔧 실제 SVG 코드 구조

### 처음 50줄:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 1000" style="background-color: #f8f9fa;">
  <!-- Title -->
  <text x="700" y="30" font-family="Arial, sans-serif" font-size="24" font-weight="bold" text-anchor="middle" fill="#232f3e">
    PetClinic AWS Network Architecture
  </text>
  <text x="700" y="55" font-family="Arial, sans-serif" font-size="14" text-anchor="middle" fill="#546e7a">
    VPC: 10.0.0.0/16 | Region: us-west-2 | Multi-AZ Deployment
  </text>
  
  <!-- Region Border -->
  <rect x="50" y="80" width="1300" height="880" fill="none" stroke="#232f3e" stroke-width="3" stroke-dasharray="10,5" rx="10"/>
  <text x="70" y="105" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="#232f3e">
    AWS Region: us-west-2 (Oregon)
  </text>
  
  <!-- VPC Border -->
  <rect x="80" y="120" width="1240" height="820" fill="#e3f2fd" stroke="#1976d2" stroke-width="2" rx="8"/>
  <text x="100" y="145" font-family="Arial, sans-serif" font-size="18" font-weight="bold" fill="#1976d2">
    VPC: petclinic-dev-vpc (10.0.0.0/16)
  </text>
  
  <!-- Internet Gateway -->
  <g id="igw">
    <rect x="630" y="160" width="140" height="60" fill="#ff9800" stroke="#e65100" stroke-width="2" rx="5"/>
    <text x="700" y="185" font-family="Arial, sans-serif" font-size="14" font-weight="bold" text-anchor="middle" fill="white">
      Internet Gateway
    </text>
    <text x="700" y="205" font-family="Arial, sans-serif" font-size="11" text-anchor="middle" fill="white">
      petclinic-dev-igw
    </text>
  </g>
  
  <!-- Internet Symbol -->
  <ellipse cx="700" cy="90" rx="30" ry="15" fill="#4caf50" stroke="#2e7d32" stroke-width="2"/>
  <text x="700" y="95" font-family="Arial, sans-serif" font-size="12" font-weight="bold" text-anchor="middle" fill="white">
    Internet
  </text>
  <line x1="700" y1="105" x2="700" y2="160" stroke="#232f3e" stroke-width="2" marker-end="url(#arrowhead)"/>
  
  <!-- AZ-A -->
  <g id="az-a">
    <rect x="120" y="250" width="560" height="650" fill="#fff9c4" stroke="#f57f17" stroke-width="2" stroke-dasharray="5,3" rx="8"/>
    <text x="140" y="275" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="#f57f17">
      Availability Zone A (us-west-2a)
    </text>
    ...
  </g>
</svg>
```

### 주요 요소:

| 태그 | 내용 | 수정 가능 부분 |
|------|------|----------------|
| `<text x="700" y="30">` | 제목 텍스트 | 위치(x,y), 내용 |
| `<rect x="630" y="160" width="140" height="60">` | Internet Gateway 박스 | 위치, 크기, 색상 |
| `fill="#ff9800"` | 배경색 (주황) | 색상 코드 |
| `stroke="#e65100"` | 테두리색 | 색상 코드 |
| `<g id="igw">` | Internet Gateway 그룹 | 전체 요소 |

---

## 💡 코드 수정 예시

### 예시 1: 텍스트 변경

#### Before:
```xml
<text x="700" y="185">Internet Gateway</text>
```

#### After:
```xml
<text x="700" y="185">인터넷 게이트웨이</text>
```

### 예시 2: 색상 변경

#### Before:
```xml
<rect fill="#ff9800" stroke="#e65100"/>
```

#### After (초록색으로):
```xml
<rect fill="#4caf50" stroke="#2e7d32"/>
```

### 예시 3: 위치 이동

#### Before:
```xml
<rect x="630" y="160" width="140" height="60"/>
```

#### After (오른쪽으로 100px):
```xml
<rect x="730" y="160" width="140" height="60"/>
```

**⚠️ 주의**: 텍스트도 같이 이동해야 합니다!
```xml
<text x="700" y="185"> → <text x="800" y="185">
```

---

## 🚨 트러블슈팅

### 문제 1: "Open With" 메뉴가 안 보여요

**해결**:
```
1. 파일 탐색기에서 우클릭 (에디터 탭에서 X)
2. 또는 Cmd/Ctrl + Shift + P → "Reopen Editor With"
```

### 문제 2: 코드가 깨져 보여요

**해결**:
```
1. 확장자 확인: .svg인지 확인
2. 인코딩 확인: UTF-8인지 확인
3. 파일 손상 확인: Git에서 복원
```

### 문제 3: 수정해도 미리보기가 안 바뀌어요

**해결**:
```
1. 파일 저장 (Cmd/Ctrl + S)
2. 미리보기 새로고침 (우클릭 → Refresh)
3. 브라우저에서 확인 (Cmd/Ctrl + Shift + V)
```

### 문제 4: XML 문법 오류

**해결**:
```
1. 태그가 제대로 닫혔는지 확인: <rect/> 또는 <rect></rect>
2. 따옴표 확인: fill="red" (쌍따옴표)
3. 주석 확인: <!-- 주석 -->
```

---

## 🎓 추가 팁

### 1. XML 문법 하이라이팅

VS Code는 자동으로 XML 하이라이팅을 적용합니다:
- **파란색**: 태그명 (`<rect>`, `<text>`)
- **빨간색**: 속성명 (`fill`, `stroke`)
- **초록색**: 속성값 (`"#ff9800"`, `"700"`)
- **회색**: 주석 (`<!-- 주석 -->`)

### 2. 자동 포맷팅

```
macOS: Cmd + Shift + I
Windows/Linux: Ctrl + Shift + I

→ XML이 자동으로 정렬됩니다!
```

### 3. 태그 접기/펼치기

```
태그 왼쪽의 ▼ ▶ 화살표 클릭
또는
macOS: Cmd + Option + [
Windows/Linux: Ctrl + Shift + [
```

### 4. 빠른 검색

```
특정 요소 찾기:
Cmd/Ctrl + F → "igw" 입력 → Internet Gateway 찾기
```

### 5. 미니맵

```
View → Show Minimap
→ 오른쪽에 전체 코드 미리보기 표시
→ 긴 SVG 파일 탐색에 유용!
```

---

## 📚 참고 자료

- [VS Code Basics](https://code.visualstudio.com/docs/getstarted/tips-and-tricks)
- [SVG Tutorial - MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial)
- [SVG Editing Guide](SVG-EDITING-GUIDE.md) - 프로젝트 문서

---

## ✅ 요약

| 상황 | 방법 |
|------|------|
| **한 번만 코드로 보고 싶을 때** | 우클릭 → "Open With" → "Text Editor" |
| **항상 코드로 보고 싶을 때** | settings.json에 `"*.svg": "default"` 추가 |
| **빠르게 전환하고 싶을 때** | Cmd/Ctrl + Shift + P → "Reopen Editor With" |
| **양쪽 동시에 보고 싶을 때** | 코드 열고 → 우클릭 → "Open Preview to Side" |

**가장 간단한 방법**: 파일 우클릭 → "Open With" → "Text Editor" ⭐
