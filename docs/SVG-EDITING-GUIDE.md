# SVG 다이어그램 수정 가이드

## 📋 개요

`network-architecture-diagram.svg` 파일은 순수 SVG 코드로 작성되어 있어, 다양한 방법으로 수정할 수 있습니다.

## 🎨 수정 방법

### Option 1: draw.io (diagrams.net) - 비주얼 에디터

#### 장점:
- ✅ GUI로 쉽게 편집
- ✅ 드래그 앤 드롭
- ✅ 다양한 AWS 아이콘 라이브러리

#### 단점:
- ⚠️ 현재 SVG는 코드로 작성되어 레이아웃이 깨질 수 있음
- ⚠️ draw.io 형식으로 다시 그려야 할 수 있음

#### 사용 방법:

1. **웹사이트 접속**: https://app.diagrams.net/

2. **파일 열기**:
   ```
   방법 A) GitHub URL로:
   - "Open Existing Diagram" → "From URL"
   - URL: https://raw.githubusercontent.com/hyh528/PetClinic-AWS-Migration/develop/docs/network-architecture-diagram.svg
   
   방법 B) 로컬 파일:
   - "Open Existing Diagram" → "From Device"
   - docs/network-architecture-diagram.svg 선택
   ```

3. **AWS 아이콘 추가** (선택사항):
   ```
   - More Shapes 클릭
   - "AWS" 검색
   - "AWS Architecture 2021" 체크
   - Apply
   ```

4. **저장**:
   ```
   File → Export as → SVG
   - Filename: network-architecture-diagram.svg
   - Transparent Background: ✅ (선택사항)
   - Include a copy of my diagram: ✅ (편집 가능하게)
   ```

### Option 2: VS Code로 텍스트 편집 - 정밀 제어

#### 장점:
- ✅ 정확한 위치 지정
- ✅ 색상 코드 직접 수정
- ✅ Git diff로 변경사항 추적

#### 단점:
- ⚠️ SVG 문법 지식 필요
- ⚠️ 좌표 계산 필요

#### SVG 구조:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1400 1000">
  <!-- 제목 -->
  <text x="700" y="30">PetClinic AWS Network Architecture</text>
  
  <!-- VPC -->
  <rect x="80" y="120" width="1240" height="820" fill="#e3f2fd"/>
  
  <!-- Internet Gateway -->
  <g id="igw">
    <rect x="630" y="160" width="140" height="60" fill="#ff9800"/>
    <text x="700" y="185">Internet Gateway</text>
  </g>
  
  <!-- 나머지 요소들... -->
</svg>
```

#### 주요 SVG 태그:

| 태그 | 용도 | 주요 속성 |
|------|------|----------|
| `<rect>` | 사각형 | `x`, `y`, `width`, `height`, `fill`, `stroke` |
| `<circle>` | 원 | `cx`, `cy`, `r`, `fill`, `stroke` |
| `<ellipse>` | 타원 | `cx`, `cy`, `rx`, `ry`, `fill` |
| `<line>` | 직선 | `x1`, `y1`, `x2`, `y2`, `stroke` |
| `<text>` | 텍스트 | `x`, `y`, `font-size`, `fill` |
| `<g>` | 그룹 | `id`, `transform` |

#### 색상 코드:

```css
/* 현재 사용 중인 색상 */
#232f3e  /* AWS Dark Blue (테두리, 텍스트) */
#1976d2  /* Blue (VPC, Private App) */
#4caf50  /* Green (Public Subnet, S3) */
#ff9800  /* Orange (NAT, IGW) */
#4fc3f7  /* Light Blue (ALB) */
#e1bee7  /* Purple (ECS) */
#fff59d  /* Yellow (Lambda) */
#ffccbc  /* Light Orange (VPC Endpoints) */
#ef9a9a  /* Light Red (DB) */
#d32f2f  /* Red (Aurora) */
```

### Option 3: Inkscape - 전문 벡터 편집기

#### 설치:
```bash
# macOS
brew install --cask inkscape

# Windows
choco install inkscape

# Linux
sudo apt install inkscape
```

#### 사용:
1. Inkscape 실행
2. File → Open → `network-architecture-diagram.svg`
3. 편집 (레이어, 객체, 텍스트 등)
4. File → Save As → SVG

### Option 4: AI에게 수정 요청 - 가장 빠름! 🤖

제게 직접 요청하시면 코드를 수정해드립니다!

#### 예시:

**요청 1**: "NAT Gateway 위치를 왼쪽으로 50px 이동해줘"
```
→ x="200" → x="150" 수정
```

**요청 2**: "Aurora 박스 색상을 더 진한 빨강으로 바꿔줘"
```
→ fill="#ef9a9a" → fill="#e57373" 수정
```

**요청 3**: "Lambda 박스에 'Bedrock' 텍스트 추가해줘"
```
→ <text> 태그 추가
```

**요청 4**: "CloudFront를 추가하고 싶어"
```
→ 새로운 <g id="cloudfront"> 그룹 추가
```

## 🔧 일반적인 수정 작업

### 1. 텍스트 변경

**찾기**:
```xml
<text x="700" y="185" ...>Internet Gateway</text>
```

**수정**:
```xml
<text x="700" y="185" ...>인터넷 게이트웨이</text>
```

### 2. 색상 변경

**찾기**:
```xml
<rect ... fill="#ff9800" stroke="#e65100" .../>
```

**수정**:
```xml
<rect ... fill="#4caf50" stroke="#2e7d32" .../>
```

### 3. 위치 이동

**찾기**:
```xml
<rect x="630" y="160" .../>
```

**수정** (오른쪽으로 100px):
```xml
<rect x="730" y="160" .../>
```

**관련 텍스트도 같이 이동**:
```xml
<text x="700" y="185" ...>  → <text x="800" y="185" ...>
```

### 4. 크기 변경

**찾기**:
```xml
<rect ... width="140" height="60" .../>
```

**수정** (더 크게):
```xml
<rect ... width="200" height="80" .../>
```

### 5. 요소 추가 (예: 새 서비스)

**복사할 템플릿**:
```xml
<g id="new-service">
  <rect x="400" y="300" width="150" height="70" 
        fill="#4fc3f7" stroke="#0277bd" stroke-width="2" rx="5"/>
  <text x="475" y="330" font-family="Arial, sans-serif" font-size="12" 
        font-weight="bold" text-anchor="middle" fill="white">
    New Service
  </text>
  <text x="475" y="348" font-family="Arial, sans-serif" font-size="10" 
        text-anchor="middle" fill="white">
    Description
  </text>
</g>
```

**좌표 계산**:
- `x`: 수평 위치 (0 = 왼쪽, 1400 = 오른쪽)
- `y`: 수직 위치 (0 = 위, 1000 = 아래)
- `text-anchor="middle"`: 텍스트 중앙 정렬 시 x는 박스 중앙

### 6. 요소 삭제

**찾아서 삭제**:
```xml
<g id="lambda">
  <!-- 전체 그룹 삭제 -->
</g>
```

## 📐 좌표 시스템

```
(0,0) ────────────────────────────────── (1400,0)
  │                                           │
  │         VPC: (80, 120)                   │
  │         ┌─────────────────────┐          │
  │         │                     │          │
  │         │  IGW: (630, 160)    │          │
  │         │                     │          │
  │         └─────────────────────┘          │
  │                                           │
(0,1000) ──────────────────────────────── (1400,1000)
```

## 🎨 색상 팔레트

### AWS 공식 색상:
```
#232f3e  /* AWS Dark Blue */
#ff9900  /* AWS Orange */
```

### 현재 다이어그램 색상:
```css
/* 네트워크 계층 */
#c8e6c9  /* Public Subnet (연두) */
#bbdefb  /* Private App (하늘) */
#ffcdd2  /* Private DB (연분홍) */

/* 서비스 */
#ff9800  /* NAT Gateway (주황) */
#4fc3f7  /* ALB (하늘) */
#e1bee7  /* ECS (보라) */
#fff59d  /* Lambda (노랑) */
#ef9a9a  /* Aurora (빨강) */
```

### 색상 변경 도구:
- [HTML Color Picker](https://www.w3schools.com/colors/colors_picker.asp)
- [Coolors.co](https://coolors.co/) - 색상 조합 생성

## 🔍 미리보기

### 브라우저에서:
```bash
# 로컬 파일 열기
open docs/network-architecture-diagram.svg

# 또는
chrome docs/network-architecture-diagram.svg
```

### VS Code에서:
```
1. SVG 파일 우클릭
2. "Open Preview" 선택
3. 수정하면 실시간 반영
```

### GitHub에서:
```
https://github.com/hyh528/PetClinic-AWS-Migration/blob/develop/docs/network-architecture-diagram.svg
```

## 💡 수정 팁

### 1. 작은 변경부터 시작
```
1. 텍스트만 수정
2. 색상만 변경
3. 위치만 이동
4. 완전히 새로운 요소 추가
```

### 2. Git으로 변경사항 추적
```bash
# 수정 전 백업
cp docs/network-architecture-diagram.svg docs/network-architecture-diagram.svg.backup

# 수정 후 비교
git diff docs/network-architecture-diagram.svg

# 마음에 안 들면 복원
git restore docs/network-architecture-diagram.svg
```

### 3. 요소별로 그룹핑
```xml
<g id="az-a">
  <!-- AZ-A 관련 모든 요소 -->
</g>

<g id="az-b">
  <!-- AZ-B 관련 모든 요소 -->
</g>
```

### 4. 주석 활용
```xml
<!-- Internet Gateway 섹션 시작 -->
<g id="igw">
  ...
</g>
<!-- Internet Gateway 섹션 끝 -->
```

## 🚨 주의사항

### 1. SVG는 픽셀이 아닌 벡터
- 확대/축소해도 선명함 유지
- 하지만 좌표는 절대값 (상대적이지 않음)

### 2. 텍스트 정렬
```xml
text-anchor="start"   <!-- 왼쪽 정렬 -->
text-anchor="middle"  <!-- 중앙 정렬 (권장) -->
text-anchor="end"     <!-- 오른쪽 정렬 -->
```

### 3. 요소 순서 중요
```xml
<!-- 뒤에 그려짐 (아래 레이어) -->
<rect fill="blue" />

<!-- 위에 그려짐 (위 레이어) -->
<rect fill="red" />
```

### 4. viewBox 변경 시 주의
```xml
<!-- 현재: 1400×1000 캔버스 -->
<svg viewBox="0 0 1400 1000">

<!-- 크기 변경 시 모든 좌표 비율 조정 필요 -->
<svg viewBox="0 0 2000 1200">
```

## 📚 참고 자료

- [SVG Tutorial - MDN](https://developer.mozilla.org/en-US/docs/Web/SVG/Tutorial)
- [draw.io Documentation](https://www.diagrams.net/doc/)
- [AWS Architecture Icons](https://aws.amazon.com/architecture/icons/)
- [SVG Color Names](https://www.w3schools.com/colors/colors_names.asp)

## 🤝 도움 요청

수정이 어렵거나 복잡한 변경이 필요하면:

1. **이슈 생성**: 어떤 부분을 어떻게 바꾸고 싶은지 설명
2. **스크린샷 첨부**: 원하는 결과물 이미지
3. **AI에게 요청**: "NAT Gateway를 3개로 늘리고 싶어" 같은 자연어 요청

저한테 말씀하시면 바로 수정해드립니다! 🚀
