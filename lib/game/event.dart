/// 전장에 떨어지는 뉴스·공시·매크로·세계정세 이벤트.
///
/// 모든 수치는 진영 중립적이다: 양수는 매수세, 음수는 매도세 편.
/// 물량 단위는 '표준 호가 잔량 칸 수'라서 종목 가격과 관계없이 같은 무게를 가진다.
enum NewsCategory {
  disclosure('공시'),
  breaking('속보'),
  report('리포트'),
  rumor('루머'),
  macro('매크로'),
  world('세계정세');

  const NewsCategory(this.label);

  final String label;
}

class MarketEvent {
  const MarketEvent({
    required this.category,
    required this.title,
    required this.detail,
    this.sentiment = 0,
    this.shock = 0,
    this.pressure = 0,
    this.pressureTicks = 0,
    this.volatility = 1,
    this.volatilityTicks = 0,
    this.wallOffset = 0,
    this.wallSize = 0,
    this.wallTag = '',
    this.followUps = const [],
    this.followUpDelay = 0,
    this.weight = 1,
  });

  final NewsCategory category;

  /// {name}은 종목명으로 바뀐다.
  final String title;
  final String detail;

  /// 즉시 바뀌는 시장 심리 (-1 ~ 1).
  final double sentiment;

  /// 즉시 쏟아지는 시장가 물량 (칸 수, +매수 / -매도).
  final double shock;

  /// pressureTicks분 동안 매 분 들어오는 시장가 물량 (칸 수, +매수 / -매도).
  final double pressure;
  final int pressureTicks;

  /// volatilityTicks분 동안 적용되는 거래량 배수.
  final double volatility;
  final int volatilityTicks;

  /// 현재가 대비 wallOffset 위치에 쌓이는 대형 벽 (음수면 매수벽, 양수면 매도벽).
  final double wallOffset;
  final double wallSize;
  final String wallTag;

  /// 후속 이벤트 후보. followUpDelay분 뒤 하나가 무작위로 터진다.
  final List<MarketEvent> followUps;
  final int followUpDelay;

  /// 무작위 뽑기 가중치.
  final int weight;

  String titleFor(String company) => title.replaceAll('{name}', company);
  String detailFor(String company) => detail.replaceAll('{name}', company);

  /// 무작위로 터지는 이벤트 덱. 후속 이벤트는 여기 없고 선행 이벤트를 통해서만 나온다.
  static const List<MarketEvent> deck = [
    // ── 기업 공시 ──
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 1,200억 주주배정 유상증자 결정',
      detail: '발행가 할인율 25%. 신주 물량 부담에 매도세 급증, 위쪽에 물량벽',
      sentiment: -0.5,
      shock: -5,
      pressure: -0.4,
      pressureTicks: 20,
      wallOffset: 0.02,
      wallSize: 6,
      wallTag: '신주물량',
      weight: 3,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 대기업 대상 제3자배정 유상증자',
      detail: '할증 발행에 전략적 투자자 등장. 유증이라고 다 악재는 아니다',
      sentiment: 0.45,
      shock: 5,
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 1주당 1주 무상증자 결정',
      detail: '권리락 착시 기대감에 개미 매수세 몰려듦',
      sentiment: 0.55,
      shock: 6,
      pressure: 0.3,
      pressureTicks: 15,
      weight: 3,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 알짜 비상장사 흡수합병 결정',
      detail: '합병비율 유리 평가. 변동성 확대 주의',
      sentiment: 0.4,
      shock: 4,
      volatility: 1.8,
      volatilityTicks: 30,
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 계열사와 합병 결정… 합병비율 논란',
      detail: '소액주주 반발. 주식매수청구가(-6%)에 거대한 매수벽 형성',
      sentiment: -0.4,
      shock: -4,
      volatility: 1.5,
      volatilityTicks: 20,
      wallOffset: -0.06,
      wallSize: 12,
      wallTag: '매수청구',
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 300억 자사주 취득 결정',
      detail: '장중 꾸준한 회사 매수 물량, 아래에 지지벽',
      sentiment: 0.2,
      pressure: 0.5,
      pressureTicks: 40,
      wallOffset: -0.02,
      wallSize: 5,
      wallTag: '자사주',
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 자사주 전량 소각 결정',
      detail: '주주환원 강화. 주당가치 상승',
      sentiment: 0.35,
      shock: 3,
    ),
    MarketEvent(
      category: NewsCategory.breaking,
      title: '{name} 최대주주, 시간외 블록딜로 지분 매각',
      detail: '할인율 8% 대량 물량이 장중으로 출회',
      sentiment: -0.35,
      shock: -8,
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 영업이익 컨센서스 40% 상회',
      detail: '어닝 서프라이즈. 기관 매수 유입',
      sentiment: 0.5,
      shock: 6,
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 적자전환… 어닝 쇼크',
      detail: '실망 매물 쏟아짐',
      sentiment: -0.5,
      shock: -6,
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 매출액 45% 규모 단일판매·공급계약 체결',
      detail: '대형 수주에 매수세 유입',
      sentiment: 0.4,
      shock: 5,
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.disclosure,
      title: '{name}, 500억 전환사채(CB) 발행 결정',
      detail: '잠재 오버행 우려. 나중에 전환 물량이 풀릴 수 있다',
      sentiment: -0.25,
      shock: -2,
      followUpDelay: 45,
      followUps: [
        MarketEvent(
          category: NewsCategory.disclosure,
          title: '{name}, CB 전환청구권 행사… 추가상장 예정',
          detail: '전환 물량이 시장에 풀린다. 위쪽에 물량벽',
          sentiment: -0.3,
          pressure: -0.5,
          pressureTicks: 20,
          wallOffset: 0.015,
          wallSize: 6,
          wallTag: '전환물량',
        ),
      ],
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.rumor,
      title: '{name}, 대기업 피인수설 확산',
      detail: '거래소 조회공시 요구. 15분 뒤 답변 예정',
      sentiment: 0.25,
      shock: 3,
      followUpDelay: 15,
      followUps: [
        MarketEvent(
          category: NewsCategory.disclosure,
          title: '{name} 조회공시 답변: "지분 매각 검토 중"',
          detail: '사실상 인정. 인수 프리미엄 기대',
          sentiment: 0.45,
          shock: 5,
        ),
        MarketEvent(
          category: NewsCategory.disclosure,
          title: '{name} 조회공시 답변: "사실무근"',
          detail: '루머 매수세 일제히 이탈',
          sentiment: -0.5,
          shock: -5,
        ),
      ],
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.breaking,
      title: '{name}, 글로벌 기술이전 협상 결과 발표 임박',
      detail: '20분 뒤 결과 발표. 양쪽 모두 숨죽임',
      sentiment: 0.1,
      volatility: 1.5,
      volatilityTicks: 20,
      followUpDelay: 20,
      followUps: [
        MarketEvent(
          category: NewsCategory.disclosure,
          title: '{name}, 1조원 규모 기술이전 계약 체결',
          detail: '대박. 매도 호가가 증발한다',
          sentiment: 0.7,
          shock: 8,
        ),
        MarketEvent(
          category: NewsCategory.breaking,
          title: '{name}, 기술이전 협상 최종 결렬',
          detail: '기대감 붕괴. 투매 발생',
          sentiment: -0.7,
          shock: -8,
        ),
      ],
    ),
    MarketEvent(
      category: NewsCategory.breaking,
      title: '해외 공매도 리서치, {name} 저격 보고서 발간',
      detail: '회계 의혹 제기. 공매도 세력 총공세',
      sentiment: -0.55,
      shock: -6,
      pressure: -0.3,
      pressureTicks: 15,
    ),
    MarketEvent(
      category: NewsCategory.breaking,
      title: '{name}, 경영진 횡령·배임 혐의 피소',
      detail: '거래정지 공포. 투매',
      sentiment: -0.7,
      shock: -8,
    ),
    MarketEvent(
      category: NewsCategory.breaking,
      title: '{name}, MSCI 지수 편입 확정',
      detail: '패시브 자금이 꾸준히 들어온다',
      sentiment: 0.3,
      pressure: 0.5,
      pressureTicks: 25,
    ),
    MarketEvent(
      category: NewsCategory.report,
      title: '증권사, {name} 목표주가 30% 상향',
      detail: '"업사이드 충분" 매수 의견',
      sentiment: 0.2,
      shock: 2,
      weight: 2,
    ),
    MarketEvent(
      category: NewsCategory.report,
      title: '증권사, {name} 투자의견 "매도"로 하향',
      detail: '보기 드문 매도 리포트',
      sentiment: -0.25,
      shock: -2,
      weight: 2,
    ),
    // ── 매크로 ──
    MarketEvent(
      category: NewsCategory.macro,
      title: '미 연준, 기준금리 0.5%p 인하 (빅컷)',
      detail: '유동성 기대에 위험자산 선호',
      sentiment: 0.3,
      shock: 3,
    ),
    MarketEvent(
      category: NewsCategory.macro,
      title: '연준 의장 "금리 인하 서두르지 않겠다"',
      detail: '매파 발언에 증시 냉각',
      sentiment: -0.3,
      shock: -3,
    ),
    MarketEvent(
      category: NewsCategory.macro,
      title: '미국 CPI 예상치 상회… 인플레이션 재점화',
      detail: '금리 인하 기대 후퇴',
      sentiment: -0.25,
      shock: -3,
    ),
    MarketEvent(
      category: NewsCategory.macro,
      title: '원·달러 환율 1,450원 돌파',
      detail: '외국인 순매도가 이어진다',
      sentiment: -0.2,
      pressure: -0.3,
      pressureTicks: 20,
    ),
    MarketEvent(
      category: NewsCategory.macro,
      title: '간밤 나스닥 3% 급등 마감',
      detail: '국내 증시 동반 강세 출발',
      sentiment: 0.25,
      shock: 2,
    ),
    MarketEvent(
      category: NewsCategory.macro,
      title: '정부, 증시 밸류업 세제 지원 발표',
      detail: '저평가 해소 기대',
      sentiment: 0.25,
      shock: 2,
    ),
    MarketEvent(
      category: NewsCategory.macro,
      title: '코스피200 선물 급락, 매도 사이드카 발동',
      detail: '프로그램 매도 5분 정지. 시장 전체 공포',
      sentiment: -0.3,
      shock: -4,
      volatility: 1.5,
      volatilityTicks: 10,
    ),
    // ── 세계정세 ──
    MarketEvent(
      category: NewsCategory.world,
      title: '중동 무력 충돌 격화… 국제유가 급등',
      detail: '지정학 리스크로 변동성 확대',
      sentiment: -0.35,
      shock: -4,
      volatility: 1.6,
      volatilityTicks: 25,
    ),
    MarketEvent(
      category: NewsCategory.world,
      title: '미·중 관세 협상 전격 타결',
      detail: '무역분쟁 완화에 수출주 강세',
      sentiment: 0.35,
      shock: 4,
    ),
    MarketEvent(
      category: NewsCategory.world,
      title: '대만해협 군사 긴장 고조',
      detail: '공급망 불안',
      sentiment: -0.3,
      shock: -3,
    ),
    MarketEvent(
      category: NewsCategory.world,
      title: '일본 금리 인상… 엔캐리 트레이드 청산 공포',
      detail: '글로벌 위험자산 동반 급락',
      sentiment: -0.4,
      shock: -5,
      volatility: 1.8,
      volatilityTicks: 20,
    ),
    MarketEvent(
      category: NewsCategory.world,
      title: '동유럽 휴전 협정 서명',
      detail: '재건 수혜 기대, 위험선호 회복',
      sentiment: 0.25,
      shock: 3,
    ),
  ];
}
