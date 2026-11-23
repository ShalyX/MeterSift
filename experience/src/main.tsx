import React, { useEffect, useMemo, useRef, useState } from "react";
import { createRoot } from "react-dom/client";

import dataset from "./cases.json";
import "./styles.css";

type Step = { id: string; label: string; status: string; tx: string; chain: number; block: number };
type MeterCase = {
  key: string; name: string; meter: string; sequence: number; settlementId: string;
  profileHash: string; features: number[]; logitQ: number; routedStatus: string;
  finalStatus: string; releasedAmountWei: number; evidenceHash: string; timeline: Step[];
};
type Data = {
  label: string; escrow: string; reactive: string; origin: string; scale: number;
  amountWei: number; featureNames: string[]; cases: { normal: MeterCase; flagged: MeterCase };
  sourceNote: string; reviewNote: string; reviewDisclaimer: string;
};
const source = dataset as Data;
const statusClass = (status: string) => status === "RELEASED" ? "released" : status === "HOLD_FOR_REVIEW" ? "held" : status === "REVIEW_APPROVED" ? "approved" : status === "RELEASE_READY" ? "ready" : "pending";
const formatNum = (n: number) => new Intl.NumberFormat("en-US", { maximumFractionDigits: 5, minimumFractionDigits: 0 }).format(n);
const short = (s: string, a = 7, b = 6) => s.slice(0, a) + "…" + s.slice(-b);
const featureLabel = (name: string) => name.replaceAll("_", " ").replace("same weekday 4w", "vs 4-week baseline").replace("log ratio", "log ratio");
const explorer = (step: Step) => step.chain === 84532 ? "https://sepolia.basescan.org/tx/" + step.tx : step.chain === 5318007 ? "https://lasna.reactscan.net/tx/" + step.tx : null;

function Icon({ name, size = 18 }: { name: string; size?: number }) {
  const paths: Record<string, React.ReactNode> = {
    arrow: <><path d="M4 12h16M13 5l7 7-7 7"/></>,
    close: <><path d="M5 5l14 14M19 5 5 19"/></>,
    check: <><path d="m4 13 5 5L20 7"/></>,
    play: <><path d="m8 5 11 7-11 7z"/></>,
    pause: <><path d="M8 5v14M16 5v14"/></>,
    previous: <><path d="M6 4v16M18 5l-10 7 10 7V5z"/></>,
    next: <><path d="M18 4v16M6 5l10 7-10 7V5z"/></>,
    link: <><path d="M12 4h8v8M20 4l-10 10"/><path d="M18 13v6H4V5h6"/></>,
    layers: <><rect x="4" y="3" width="16" height="18" rx="3"/><path d="M8 8h8M8 12h8M8 16h5"/></>,
    pulse: <><path d="M2 12h5l3-7 4 14 3-7h5"/></>
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{paths[name] || paths.pulse}</svg>;
}

function Logo() {
  return <span className="logo"><span className="logo-symbol" aria-hidden="true"><i/><i/><i/></span><span>meter<span className="logo-bold">sift</span></span></span>;
}

function App() {
  const [route, setRoute] = useState(window.location.pathname);
  const [caseKey, setCaseKey] = useState<"normal" | "flagged">(() => new URLSearchParams(window.location.search).get("case") === "normal" ? "normal" : "flagged");
  const [stepIndex, setStepIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [playbackSpeed, setPlaybackSpeed] = useState<0.5 | 1 | 1.5>(1);
  const [evidence, setEvidence] = useState(false);
  const [selectedFeature, setSelectedFeature] = useState<number | null>(null);
  const [mode, setMode] = useState<"recorded" | "current">("recorded");
  const [liveStatus, setLiveStatus] = useState("NOT REQUESTED");
  const [liveDetail, setLiveDetail] = useState("");
  const [reducedMotion, setReducedMotion] = useState(false);
  const closeRef = useRef<HTMLButtonElement>(null);
  const openRef = useRef<HTMLButtonElement>(null);
  const returnFocusRef = useRef<HTMLElement | null>(null);
  const swipeStartRef = useRef<{ x: number; y: number } | null>(null);
  const queryIdRef = useRef(0);
  const stageRef = useRef<HTMLElement>(null);
  const current = source.cases[caseKey];
  const other = source.cases[caseKey === "normal" ? "flagged" : "normal"];
  const stages = current.timeline;
  const active = stages[Math.min(stepIndex, stages.length - 1)];
  const amount = (source.amountWei / 1e18).toFixed(5);
  const motionOn = playing && !reducedMotion && mode === "recorded";
  const currentStatus = mode === "recorded" ? active.status : liveStatus;

  useEffect(() => {
    const media = window.matchMedia("(prefers-reduced-motion: reduce)");
    const change = () => setReducedMotion(media.matches);
    change();
    media.addEventListener("change", change);
    return () => media.removeEventListener("change", change);
  }, []);

  useEffect(() => {
    if (!playing || mode !== "recorded" || reducedMotion) return;
    const timer = window.setInterval(() => {
      setStepIndex(prev => {
        if (prev >= stages.length - 1) {
          setPlaying(false);
          return prev;
        }
        return prev + 1;
      });
    }, Math.round(1600 / playbackSpeed));
    return () => window.clearInterval(timer);
  }, [playing, stages.length, mode, reducedMotion, playbackSpeed]);

  useEffect(() => {
    const background = Array.from(document.querySelectorAll<HTMLElement>(".site > header, .site > main, .site > footer, .site > .truth-ribbon"));
    if (evidence) {
      returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      background.forEach(element => { element.inert = true; });
      document.body.style.overflow = "hidden";
      closeRef.current?.focus();
    } else {
      background.forEach(element => { element.inert = false; });
      document.body.style.overflow = "";
      returnFocusRef.current?.focus();
      returnFocusRef.current = null;
    }
    return () => { background.forEach(element => { element.inert = false; }); document.body.style.overflow = ""; };
  }, [evidence]);

  useEffect(() => {
    const pauseWhenHidden = () => { if (document.hidden) setPlaying(false); };
    document.addEventListener("visibilitychange", pauseWhenHidden);
    return () => document.removeEventListener("visibilitychange", pauseWhenHidden);
  }, []);

  useEffect(() => {
    const target = stageRef.current;
    if (!target || typeof IntersectionObserver === "undefined") return;
    const observer = new IntersectionObserver(entries => {
      if (!entries[0]?.isIntersecting) setPlaying(false);
    }, { threshold: 0.05 });
    observer.observe(target);
    return () => observer.disconnect();
  }, [route]);

  useEffect(() => {
    const onPop = () => {
      setRoute(window.location.pathname);
      const p = new URLSearchParams(window.location.search);
      setCaseKey(p.get("case") === "normal" ? "normal" : "flagged");
      setStepIndex(0);
    };
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, []);

  function go(page: string) {
    window.history.pushState({}, "", page);
    setRoute(window.location.pathname);
    setStepIndex(0);
    setPlaying(false);
    window.scrollTo({ top: 0, behavior: "instant" });
  }

  function chooseCase(k: "normal" | "flagged") {
    queryIdRef.current += 1;
    setCaseKey(k);
    setStepIndex(0);
    setPlaying(false);
    setSelectedFeature(null);
    setLiveStatus("NOT REQUESTED");
    setLiveDetail("");
    const url = new URL(window.location.href);
    url.searchParams.set("case", k);
    window.history.replaceState({}, "", url.toString());
  }

  async function refreshLive() {
    const requestId = ++queryIdRef.current;
    setMode("current");
    setPlaying(false);
    setLiveStatus("CHECKING");
    setLiveDetail("");
    try {
      const { Contract, JsonRpcProvider } = await import("ethers");
      const provider = new JsonRpcProvider("https://sepolia.base.org", 84532);
      const network = await provider.getNetwork();
      if (network.chainId !== 84532n) throw new Error("Incorrect chain");
      const escrow = new Contract(source.escrow, [
        "function settlements(bytes32) view returns(address meter,uint64 sequence,uint256 amount,uint8 status,int256 logitQ,uint32 modelVersion,bytes32 evidenceHash,bool decisionRecorded)"
      ], provider);
      const result = await escrow.settlements(current.settlementId);
      const statuses = ["NONE", "PENDING", "RELEASE_READY", "HOLD_FOR_REVIEW", "REVIEW_APPROVED", "RELEASED", "REFUNDED"];
      const state = statuses[Number(result.status)] || "UNKNOWN";
      if (requestId !== queryIdRef.current) return;
      setLiveStatus(state);
      setLiveDetail("Read-only Base Sepolia RPC · block state at query · " + formatNum(Number(result.amount)) + " wei remaining");
    } catch (error) {
      if (requestId !== queryIdRef.current) return;
      setLiveStatus("UNAVAILABLE");
      setLiveDetail("RPC request failed or browser access blocked. No cached state is represented as live. " + (error instanceof Error ? error.message.slice(0, 120) : ""));
    }
  }

  function jump(next: number) {
    setPlaying(false);
    setStepIndex(Math.min(stages.length - 1, Math.max(0, next)));
  }

  function endStageSwipe(e: React.TouchEvent) {
    const started = swipeStartRef.current;
    swipeStartRef.current = null;
    if (!started || mode !== "recorded" || window.innerWidth > 650) return;
    const touch = e.changedTouches[0];
    if (!touch) return;
    const dx = touch.clientX - started.x;
    const dy = touch.clientY - started.y;
    if (Math.abs(dx) >= 65 && Math.abs(dy) < 60) jump(stepIndex + (dx < 0 ? 1 : -1));
  }

  const summary = caseKey === "flagged"
    ? "The screening callback held this synthetic case for review. An authorized reviewer committed a minimal record; a separate payout followed."
    : "This synthetic profile was release-ready after the Reactive callback. A separate operator payout completed settlement.";
  const showRelease = active.status === "REVIEW_APPROVED" && caseKey === "flagged";

  return <div className="site">
    <header className="topbar">
      <button className="brand-click" onClick={() => go("/")} aria-label="MeterSift home"><Logo /></button>
      <nav aria-label="Primary navigation">
        <button className={route === "/" ? "nav-active" : ""} onClick={() => go("/")}>Discover</button>
        <button className={route === "/explore" ? "nav-active" : ""} onClick={() => go("/explore?case=" + caseKey)}>Explore</button>
        <button className={route === "/proof" ? "nav-active" : ""} onClick={() => go("/proof")}>Chain proof</button>
      </nav>
      <button className="top-cta" onClick={() => go("/explore?case=flagged")}>Explore the case <Icon name="arrow" size={16}/></button>
    </header>
    <div className="truth-ribbon"><span className="proof-dot"/><span>RECORDED TESTNET PROOF</span><b>•</b><span>SYNTHETIC METER PROFILES</span><b>•</b><span>NO AUTOMATED PAYOUT</span></div>

    {route === "/" ? <main>
      <section className="landing-hero">
        <div className="hero-copy">
          <span className="eyebrow dark"><span className="eyebrow-line"/> MEET METERSIFT / REACTIVE MEETS AI</span>
          <h1>Electricity delivered.<br/>Meter data doesn't add up.<br/><em>Who gets paid?</em></h1>
          <p>A community energy operator owes payment to the local supplier who delivered the power. Paying against a questionable meter profile risks overpaying; holding the settlement risks delaying money legitimately owed. MeterSift screens profile submissions from authorized meter accounts and routes uncertain cases to human review — a separate authorized action controls release.</p>
          <div className="hero-actions">
            <button className="btn-primary" onClick={() => go("/explore?case=flagged")}>Explore the settlement <Icon name="arrow"/></button>
            <button className="btn-text" onClick={() => go("/proof")}>Follow the real transactions <Icon name="link" size={16}/></button>
          </div>
          <div className="hero-stats"><div><strong>02</strong><span>funded testnet paths</span></div><div><strong>04</strong><span>locked core capabilities</span></div><div><strong>01</strong><span>human decision boundary</span></div></div>
        </div>
        <div className="hero-visual">
          <div className="hero-topline"><span>THE SIGNAL JOURNEY</span><span className="tiny-pill">DEMONSTRATION / HISTORICAL</span></div>
          <SignalGraphic caseKey="flagged" stepIndex={3} motionOn={false} isHero /><MobileSignal caseKey="flagged" screened={true} />
          <div className="hero-visual-foot"><span><i className="dot-aqua"/> PROFILE ENTERS</span><span><i className="dot-amber"/> REVIEW ROUTE</span><span><i className="dot-green"/> SEPARATE PAYOUT</span></div>
        </div>
        <span className="side-notation">01 / SIGNAL → DECISION</span>
      </section>
      <section className="value-strip">
        <div><span>01 / SIFT</span><h2>Read the signal, not just the score.</h2><p>Inspect ten derived model features from the synthetic profiles and follow the screening route.</p></div>
        <div><span>02 / ROUTE</span><h2>Watch Reactive make the difference.</h2><p>The neural screen runs inside Reactive's <code>react()</code> handler on Lasna — no off-chain inference service or keeper. Its authenticated callback updates the Base Sepolia escrow.</p></div>
        <div><span>03 / DECIDE</span><h2>Human judgment stays in the loop.</h2><p>Held cases require review and a separately authorized payout.</p></div>
      </section>
      <section className="landing-next">
        <div><span className="eyebrow dark">THE MOMENT THAT MATTERS</span><h2>From a flag to an accountable outcome.</h2><p>The flagged case stayed held until the reviewer committed a record. Release was a second, distinct testnet transaction.</p></div>
        <div className="next-right"><div className="ring-demo"><span>HOLD</span><strong>→</strong><span>REVIEW</span><strong>→</strong><span>RELEASE</span></div><button className="btn-primary" onClick={() => go("/explore?case=flagged")}>See the actual evidence <Icon name="arrow"/></button></div>
      </section>
    </main> : null}

    {route === "/explore" ? <main className="explorer">
      <div className="explore-heading"><div><span className="eyebrow dark">THE SETTLEMENT PLAYGROUND / HISTORICAL PROOF</span><h1>Follow the <em>signal.</em></h1><p>Two funded cases. One Reactive neural screen. A decision path you can explore.</p></div><div className="context-code"><span>CHAIN</span><strong>Base Sepolia ↔ Lasna</strong><span>STATUS / SYNTHETIC TESTNET</span></div></div>
      <div className="explore-toolbar">
        <div className="case-switch" aria-label="Choose verified case"><button className={caseKey === "normal" ? "selected" : ""} onClick={() => chooseCase("normal")}> <span className="switch-dot normal"/> Routine profile <small>SEQ 01</small></button><button className={caseKey === "flagged" ? "selected" : ""} onClick={() => chooseCase("flagged")}><span className="switch-dot abnormal"/> Exception profile <small>SEQ 02</small></button></div>
        <div className="mode-switch"><button className={mode === "recorded" ? "selected" : ""} onClick={() => {queryIdRef.current += 1; setMode("recorded"); setPlaying(false);}}>Recorded replay</button><button className={mode === "current" ? "selected" : ""} onClick={refreshLive}>Read-only current</button></div>
      </div>
      <section ref={stageRef} className="live-stage" aria-label="Interactive MeterSift screening illustration">
        <div className="stage-top"><span><i className="signal-blip"/> {mode === "recorded" ? "RECORDED / IMMUTABLE TESTNET STORY" : "CURRENT / READ-ONLY CONTRACT QUERY"}</span><span className="stage-case">CASE {String(current.sequence).padStart(2, "0")} / 0.00001 TEST ETH</span></div>
        <div className="stage-content" onTouchStart={e=>{ const t=e.touches[0]; swipeStartRef.current = t ? {x:t.clientX,y:t.clientY} : null; }} onTouchEnd={endStageSwipe}><SignalGraphic caseKey={caseKey} stepIndex={mode === "recorded" ? stepIndex : -1} motionOn={motionOn} isHero={false}/><MobileSignal caseKey={caseKey} screened={mode === "recorded" && stepIndex >= (caseKey === "flagged" ? 3 : 2)} /></div>
        <div className="stage-bottom"><div><small>CURRENT CHAPTER</small><strong>{mode === "recorded" ? active.label : "Read-only on-chain settlement"}</strong></div><span className={"state-pill " + statusClass(currentStatus)} role="status" aria-live="polite" aria-atomic="true">{currentStatus.replaceAll("_", " ")}</span></div>
      </section>
      <section className="journey-panel" aria-label="Recorded settlement timeline">
        <div className="journey-header"><div><span className="eyebrow dark">REPLAY THE CHAIN</span><h2>One event at a time.</h2></div><div className="playback"><button onClick={() => jump(stepIndex-1)} aria-label="Previous recorded stage" disabled={mode !== "recorded" || stepIndex===0}><Icon name="previous"/></button><button className="play-button" onClick={() => { if (reducedMotion) jump(stepIndex===stages.length-1?0:stepIndex+1); else { if (stepIndex===stages.length-1) setStepIndex(0); setPlaying(v=>!v); }}} aria-label={reducedMotion ? (stepIndex===stages.length-1 ? "Restart recorded replay" : "Next recorded stage (reduced motion)") : playing ? "Pause recorded replay" : "Play recorded replay"} disabled={mode!=="recorded"}><Icon name={playing ? "pause" : "play"}/></button><button onClick={() => jump(stepIndex+1)} aria-label="Next recorded stage" disabled={mode !== "recorded" || stepIndex===stages.length-1}><Icon name="next"/></button><span>{stepIndex+1} / {stages.length}</span><label className="speed-control">Speed <select aria-label="Recorded replay speed" value={playbackSpeed} disabled={mode!=="recorded" || reducedMotion} onChange={e=>setPlaybackSpeed(Number(e.target.value) as 0.5 | 1 | 1.5)}><option value="0.5">0.5×</option><option value="1">1×</option><option value="1.5">1.5×</option></select></label></div></div>
        <div className="timeline" aria-label="Recorded chapters">{stages.map((s,i)=><button key={s.id} aria-label={"Chapter "+(i+1)+": "+s.label+" — "+s.status.replaceAll("_"," ")} className={"timeline-step " + (i<=stepIndex ? "passed " : "") + (stepIndex===i?"active":"")} aria-current={stepIndex===i?"step":undefined} onClick={()=>jump(i)} disabled={mode !== "recorded"}><span className="timeline-node"><span/></span><span className="timeline-label">{s.label}</span><small>{i===stepIndex ? s.status.replaceAll("_"," ") : "0"+(i+1)}</small></button>)}</div>
        <p className="journey-explainer">{mode==="recorded" ? summary : (liveDetail || "Press read-only current to query the deployed escrow without signing or submitting a transaction.")}</p>
        {showRelease && mode === "recorded" ? <button className="recorded-release" onClick={()=>jump(stepIndex+1)}><Icon name="play" size={15}/> Play separate recorded release event <span>NOT A TRANSACTION</span></button> : null}
      </section>
      <section className="features-section">
        <div className="section-lead"><div><span className="eyebrow dark">REAL SOURCE / TEN DERIVED FEATURES</span><h2>The shape of the <em>signal.</em></h2><p>These are actual fixed-point model inputs from the synthetic funded profiles, not reconstructed hourly meter readings.</p></div><span className="feature-note">COMPARISON / PER-FEATURE SCALE</span></div>
        <FeatureChart current={current} other={other} selected={selectedFeature} onSelect={setSelectedFeature}/>
      </section>
      <section className="proof-dock"><div><span className="eyebrow dark">LOOK UNDER THE SURFACE</span><h2>Every ripple has a receipt.</h2><p>Explore source identity, committed profile, Reactive execution, callback and the human review boundary.</p><button ref={openRef} className="btn-primary" onClick={()=>setEvidence(true)}>Open evidence chamber <Icon name="layers"/></button></div><div className="proof-dock-route"><div><b>BASE</b><span>Account-signed origin</span></div><Icon name="arrow"/><div><b>LASNA</b><span>Neural screening</span></div><Icon name="arrow"/><div><b>BASE</b><span>Escrow callback</span></div></div></section>
    </main> : null}

    {route === "/proof" ? <main className="proof-page"><div className="proof-header"><span className="eyebrow dark">VERIFY, DON'T TAKE OUR WORD</span><h1>Follow the <em>proof.</em></h1><p>These are actual synthetic testnet transactions. Recorded events do not imply activity happening now.</p><button className="btn-primary" onClick={()=>go("/explore?case=flagged")}>Back to the story <Icon name="arrow"/></button></div><div className="proof-columns">{(["normal","flagged"] as const).map(k=><section key={k} className="receipt-group"><div className="receipt-heading"><span className={"switch-dot " + (k==="normal"?"normal":"abnormal")}/><h2>{source.cases[k].name}</h2><small>SEQ {source.cases[k].sequence}</small></div>{source.cases[k].timeline.map(s=><div className="receipt-row" key={s.id}><div><strong>{s.label}</strong><span>{s.chain===84532?"Base Sepolia":"Reactive Lasna"} · block {s.block}</span></div><span className="mono">{short(s.tx)}</span>{explorer(s)?<a href={explorer(s)!} target="_blank" rel="noopener noreferrer" aria-label={"Open "+s.label+" on "+(s.chain===84532?"BaseScan":"Reactscan")}><Icon name="link"/></a>:<span className="no-link">Lasna</span>}</div>)}</section>)}</div><aside className="proof-limitations"><h3>What this demonstrates</h3><p>Two real funded testnet settlements completed. The normal profile reached RELEASE_READY before separate payout; the flagged profile required an authorized replay, a review commitment and separate release. The committed synthetic review note says only "Approve". Its hash proves commitment matching, not substantive investigation. Model performance has not been validated with field data.</p><p>Deployed escrow: <span className="mono">{source.escrow}</span></p></aside></main> : null}

    <footer className="footer"><Logo/><div><p>Built to show the decision, not declare a verdict.</p><span>MeterSift · Reactive Meets AI · Synthetic profiles and testnet funds only.</span></div><button onClick={()=>go("/proof")}>Trace the evidence <Icon name="arrow" size={16}/></button></footer>

    {evidence ? <div className="evidence-overlay" role="presentation" onMouseDown={(e)=> {if(e.target===e.currentTarget) setEvidence(false);}}><aside className="evidence-sheet" role="dialog" aria-modal="true" aria-label="Settlement evidence and provenance" onKeyDown={e=>{if(e.key==="Escape") setEvidence(false); if(e.key==="Tab"){const d=e.currentTarget;const f=Array.from(d.querySelectorAll<HTMLElement>("button,a[href]"));const first=f[0],last=f[f.length-1];if(e.shiftKey && document.activeElement===first){e.preventDefault();last.focus();}else if(!e.shiftKey && document.activeElement===last){e.preventDefault();first.focus();}}}}><div className="sheet-heading"><div><span className="eyebrow dark">EVIDENCE CHAMBER / SYNTHETIC TESTNET</span><h2>Look closer.</h2></div><button ref={closeRef} className="icon-only" onClick={()=>setEvidence(false)} aria-label="Close evidence"><Icon name="close"/></button></div><div className="evidence-summary"><span className={"state-pill "+statusClass(currentStatus)}>{currentStatus.replaceAll("_"," ")}</span><p>{summary}</p></div><div className="evidence-field"><small>METER ACCOUNT / EOA SIGNER</small><p className="mono">{current.meter}</p><span>An account signature is not physical-meter attestation.</span></div><div className="evidence-field"><small>PROFILE COMMITMENT / SHA-256</small><p className="mono">{current.profileHash}</p><span>Commitment does not prove the underlying readings were truthful.</span></div><div className="evidence-field"><small>SETTLEMENT ID</small><p className="mono">{current.settlementId}</p></div><div className="evidence-field"><small>RECORDED MODEL LOGIT (FIXED-POINT / 1e6)</small><p className="metric-mono">{formatNum(current.logitQ/1000000)}</p><span>A screening signal, not a theft probability or customer verdict.</span></div>{caseKey==="flagged"?<div className="evidence-field highlighted"><small>HUMAN REVIEW COMMITMENT</small><p className="mono">{current.evidenceHash}</p><p className="review-note">Notes: "{source.reviewNote}"</p><span>{source.reviewDisclaimer}</span></div>:null}<div className="sheet-receipts"><h3>Actual recorded transactions</h3>{stages.map(s=><div key={s.id}><span>{s.label}</span><span className="mono">{short(s.tx)}</span>{explorer(s)?<a target="_blank" rel="noopener noreferrer" href={explorer(s)!} aria-label={"View "+s.label+" receipt"}><Icon name="link" size={15}/></a>:<span className="no-link">Lasna</span>}</div>)}</div><p className="sheet-bottom-note">No transaction is submitted from this experience. All replayed transactions occurred earlier on testnets.</p></aside></div> : null}
  </div>;
}

function SignalGraphic({caseKey,stepIndex,motionOn,isHero}:{caseKey:"normal"|"flagged";stepIndex:number;motionOn:boolean;isHero:boolean}) {
  const flagged=caseKey==="flagged";
  const routeActive=isHero || stepIndex >= (flagged ? 3 : 2);
  const resolved=isHero || stepIndex >= (flagged ? 5 : 3);
  return <svg className={"signal-graphic "+(motionOn?"is-moving":"")} viewBox="0 0 1050 420" role="img" aria-label="Explanatory flowing signal: meter profile through Reactive neural screening to human review or release path. Illustration of recorded testnet proof, not raw readings.">
    <defs><linearGradient id="signal-line" x1="0" x2="1"><stop offset="0%" stopColor="#46dbde"/><stop offset="55%" stopColor="#92ebd8"/><stop offset="100%" stopColor="#687bff"/></linearGradient><linearGradient id="amber-line"><stop stopColor="#eeb75b"/><stop offset="100%" stopColor="#ffce79"/></linearGradient><radialGradient id="gate-aura"><stop stopColor="#5368ef" stopOpacity=".3"/><stop offset="100%" stopColor="#5368ef" stopOpacity="0"/></radialGradient><filter id="small-glow"><feGaussianBlur stdDeviation="5"/></filter></defs>
    <circle cx="490" cy="202" r="185" fill="url(#gate-aura)"/>
    <g className="contours" fill="none" stroke="#39545c" strokeWidth="1" opacity=".42"><path d="M25 330C185 306 281 352 420 323S680 281 1030 340"/><path d="M25 355C185 327 303 377 432 346S672 319 1030 363"/><path d="M25 379C197 343 289 406 449 371S683 337 1030 391"/></g>
    <g className="signal-source"><circle cx="88" cy="202" r="72" fill="#132d38" stroke="#315965" strokeWidth="1"/><circle cx="88" cy="202" r="53" fill="none" stroke="#3b7b87" strokeDasharray="2 10"/><path d="M43 203l19-26 21 48 25-54 21 32" fill="none" stroke="#67dfdf" strokeWidth="4" strokeLinecap="round"/><text x="88" y="106" textAnchor="middle" className="svg-label">METER PROFILE</text><text x="88" y="304" textAnchor="middle" className="svg-sublabel">SYNTHETIC DATA</text></g>
    <g fill="none" strokeLinecap="round"><path d="M161 202C245 202 283 202 399 202" stroke="#234858" strokeWidth="24"/><path d="M161 202C245 202 283 202 399 202" stroke="url(#signal-line)" strokeWidth="3.5" strokeDasharray="10 13" className="flow-line"/></g>
    <g className="gate"><circle cx="490" cy="202" r="87" fill="#152732" stroke="#456279" strokeWidth="1.5"/><circle cx="490" cy="202" r="70" fill="none" stroke="#596c7f" strokeDasharray="4 10"/><circle cx="490" cy="202" r="53" fill="#192936" stroke="#7b9bba" strokeWidth="1"/><path d="M474 170v64M490 157v89M506 170v64" stroke="#91dcdf" strokeWidth="3" strokeLinecap="round"/><circle cx="490" cy="202" r="103" fill="none" stroke={flagged?"#eeb75b":"#8adfe0"} strokeOpacity=".38" strokeWidth="1"/><text x="490" y="70" textAnchor="middle" className="svg-label">REACTIVE / LASNA</text><text x="490" y="325" textAnchor="middle" className="svg-sublabel">NEURAL SCREENING</text></g>
    <path d="M578 201C673 201 674 107 762 107H894" fill="none" stroke="#34515e" strokeWidth="17" strokeLinecap="round"/>
    <path d="M578 204C673 204 685 282 761 282H894" fill="none" stroke="#34515e" strokeWidth="17" strokeLinecap="round"/>
    <path d="M578 201C673 201 674 107 762 107H894" fill="none" stroke={routeActive && !flagged ? "#6fdfc1" : "#4b6475"} strokeWidth={routeActive && !flagged ? 4 : 2} strokeLinecap="round" className={routeActive && !flagged ? "flow-line" : ""}/>
    <path d="M578 204C673 204 685 282 761 282H894" fill="none" stroke={routeActive && flagged ? "#efb45b" : "#4b6475"} strokeWidth={routeActive && flagged ? 4 : 2} strokeLinecap="round" className={routeActive && flagged ? "flow-line" : ""}/>
    <g transform="translate(924 105)"><circle r="49" fill={flagged?"#203640":"#244d47"} stroke={flagged?"#426170":"#6ccda4"} strokeWidth="2"/><circle r="33" fill="none" stroke={flagged?"#527381":"#9bebc8"} strokeDasharray="3 7"/><path d="m-13 0 8 9 18-19" fill="none" stroke={flagged?"#607e85":"#a8f9d3"} strokeWidth="4" strokeLinecap="round" strokeLinejoin="round"/></g>
    <g transform="translate(924 284)"><circle r="54" fill={flagged?"#493522":"#202e3b"} stroke={flagged?"#f0bc64":"#4e6b7a"} strokeWidth="2"/><circle r="39" fill="none" stroke={flagged?"#edb95e":"#5d8790"} strokeDasharray="5 9"/><path d="m0-19 17 30h-34z" fill="none" stroke={flagged?"#ffc96f":"#7c9bab"} strokeWidth="3"/><path d="M0-7v10M0 9v2" stroke={flagged?"#ffc96f":"#7c9bab"} strokeWidth="3" strokeLinecap="round"/></g>
    <text x="924" y="174" textAnchor="middle" className="svg-label">{flagged?"ROUTINE LANE":"RELEASE READY"}</text>
    <text x="924" y="357" textAnchor="middle" className="svg-label">{flagged?"HOLD FOR REVIEW":"REVIEW LANE"}</text>
    <g className={routeActive?"route-glow":""}><circle cx="680" cy={flagged?245:153} r="7" fill={flagged?"#f0bd6c":"#63e3c7"}/><circle cx="680" cy={flagged?245:153} r="17" fill="none" stroke={flagged?"#f0bd6c":"#63e3c7"} opacity=".45" strokeWidth="1"/></g>
    {resolved && <g><circle cx="1015" cy={flagged?284:105} r="8" fill="#6de7b7"/><text x="820" y={flagged?401:37} textAnchor="middle" className="svg-sublabel">SEPARATE RELEASE RECORDED</text></g>}
    <text x="35" y="29" className="svg-corner">ILLUSTRATIVE SIGNAL ROUTE / NOT A RAW HOURLY READING</text>
  </svg>;
}

function MobileSignal({caseKey,screened}:{caseKey:"normal"|"flagged";screened:boolean}) {
  const flagged=caseKey==="flagged";
  return <svg className="mobile-signal" viewBox="0 0 390 430" role="img" aria-label="Illustrative vertical screening journey with a selected route. Not raw meter readings.">
    <defs><linearGradient id="mobileflow"><stop stopColor="#76e8df"/><stop offset="100%" stopColor="#6d82ef"/></linearGradient></defs>

    <g transform="translate(195 78)"><circle r="42" fill="#1b3945" stroke="#4a8390"/><path d="M-23 2l12-17 13 31 11-30 12 16" fill="none" stroke="#6ae1db" strokeWidth="3" strokeLinecap="round"/><text x="0" y="-54" textAnchor="middle" className="svg-label">METER PROFILE</text></g>
    <path d="M195 120v56" stroke="#327082" strokeWidth="12" strokeLinecap="round"/><path d="M195 122v52" stroke="#7cddd9" strokeWidth="3" strokeDasharray="6 10" className="flow-line"/>
    <g transform="translate(195 236)"><circle r="57" fill="#1b303d" stroke="#5c839c"/><circle r="44" fill="none" stroke="#82bdcb" strokeDasharray="4 8"/><path d="M-15-22v44M0-29v58M15-22v44" stroke="#9ce9dd" strokeWidth="3" strokeLinecap="round"/><text x="0" y="-75" textAnchor="middle" className="svg-label">REACTIVE / LASNA</text><text x="0" y="86" textAnchor="middle" className="svg-sublabel">NEURAL FILTER</text></g>
    <path d="M160 277C117 313 92 321 79 350" fill="none" stroke={screened && !flagged ? "#5fdbbd" : "#385766"} strokeWidth={screened && !flagged ? 6 : 3} strokeLinecap="round"/>
    <path d="M230 277C272 313 298 323 311 350" fill="none" stroke={screened && flagged ? "#f1bb62" : "#385766"} strokeWidth={screened && flagged ? 6 : 3} strokeLinecap="round"/>
    <circle cx="79" cy="367" r="26" fill={flagged?"#213842":"#2b5b4f"} stroke={flagged?"#537180":"#76ddbf"} strokeWidth="2"/><path d="m66 365 9 9 16-17" fill="none" stroke={flagged?"#78969c":"#91f1cf"} strokeWidth="3"/>
    <circle cx="311" cy="367" r="26" fill={flagged?"#5b422b":"#203742"} stroke={flagged?"#f8c06a":"#557484"} strokeWidth="2"/><path d="m311 347 15 27h-30z" fill="none" stroke={flagged?"#ffd18c":"#7794a1"} strokeWidth="3"/>
    <text x="79" y="411" textAnchor="middle" className="svg-sublabel">RELEASE READY</text>
    <text x="311" y="411" textAnchor="middle" className="svg-sublabel">HOLD FOR REVIEW</text>
  </svg>;
}

function FeatureChart({current,other,selected,onSelect}:{current:MeterCase;other:MeterCase;selected:number|null;onSelect:(i:number|null)=>void}) {
  const rows=useMemo(()=>source.featureNames.map((name,i)=>({name,index:i,v:current.features[i]/source.scale,other:other.features[i]/source.scale})),[current,other]);
  return <div className="feature-shell"><div className="feature-graph" role="group" aria-label="Comparison of ten real derived features with separate per-feature scales">{rows.map(f=>{
    const max=Math.max(Math.abs(f.v),Math.abs(f.other),.05);
    const x1=50+f.index%5*181, y1=65+Math.floor(f.index/5)*155;
    const origin=x1+68;
    const yCurrent=y1-42*f.v/max, yOther=y1-42*f.other/max;
    return <button className={"feature-cell "+(selected===f.index?"chosen":"")} key={f.name} onClick={()=>onSelect(selected===f.index?null:f.index)} onKeyDown={e=>{ const columns=window.innerWidth<=650?2:window.innerWidth<=980?3:5; const delta=e.key==="ArrowRight"?1:e.key==="ArrowLeft"?-1:e.key==="ArrowDown"?columns:e.key==="ArrowUp"?-columns:0; if(!delta)return; e.preventDefault(); const next=(f.index+delta+rows.length)%rows.length; e.currentTarget.parentElement?.querySelectorAll<HTMLButtonElement>(".feature-cell")[next]?.focus(); onSelect(next); }} aria-label={featureLabel(f.name)+", selected "+formatNum(f.v)+", comparison "+formatNum(f.other)}>
      <svg viewBox="0 0 170 100" aria-hidden="true"><line x1="17" y1="50" x2="153" y2="50" stroke="#d2dad6" strokeWidth="1"/><line x1="85" y1="8" x2="85" y2="92" stroke="#e7e9e4" strokeDasharray="2 5"/><line x1={85} y1="50" x2={85 + 58*f.v/max} y2="50" stroke="#36b9c5" strokeWidth="10" strokeLinecap="round"/><circle cx={85+58*f.v/max} cy="50" r="7" fill="#173d47" stroke="#67e8d8" strokeWidth="3"/><circle cx={85+58*f.other/max} cy="72" r="4" fill="#dfac5e"/><text x="18" y="23" className="feature-number">{String(f.index+1).padStart(2,"0")}</text></svg>
      <strong>{featureLabel(f.name)}</strong><span className="feature-values">{formatNum(f.v)} <i/> <small>{formatNum(f.other)}</small></span>
    </button>;
  })}</div><div className="chart-key"><div><i className="key-current"/> Selected: {current.name}</div><div><i className="key-other"/> Other: {other.name}</div><span>Each feature has its own scale. Values are derived, not hourly energy samples.</span></div>{selected!==null ? <div className="feature-inspector"><span>FEATURE {String(selected+1).padStart(2,"0")}</span><strong>{featureLabel(rows[selected].name)}</strong><p>Selected profile: <b>{formatNum(rows[selected].v)}</b>. Other profile: <b>{formatNum(rows[selected].other)}</b>. These are synthetic derived model inputs; comparison alone does not prove theft or manipulation.</p><button onClick={()=>onSelect(null)} aria-label="Close feature details"><Icon name="close" size={15}/></button></div>:null}</div>;
}

createRoot(document.getElementById("root")!).render(<React.StrictMode><App/></React.StrictMode>);
