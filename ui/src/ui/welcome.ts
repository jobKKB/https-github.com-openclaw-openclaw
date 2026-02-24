import { html, css, LitElement } from "lit";
import { customElement, state, property } from "lit/decorators.js";

/**
 * 舟岱自动化小助手 - 欢迎引导页
 * 首次访问时全屏展示，用户接受条款后进入正式界面
 */

@customElement("zhoudai-welcome")
export class ZhoudaiWelcome extends LitElement {
  @property({ type: Function }) onAccept: (() => void) | null = null;
  @state() private step = 0; // 0=欢迎动画, 1=介绍, 2=条款, 3=完成
  @state() private checked = false;
  @state() private animating = false;

  static styles = css`
    :host {
      display: block;
      position: fixed;
      inset: 0;
      z-index: 9999;
      background: #0d1117;
      color: #c9d1d9;
      font-family: "Noto Sans SC", -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif;
      overflow: hidden;
    }

    /* ── 粒子背景 ── */
    .bg-canvas {
      position: absolute;
      inset: 0;
      overflow: hidden;
      pointer-events: none;
    }
    .bg-dot {
      position: absolute;
      border-radius: 50%;
      background: rgba(29, 111, 164, 0.15);
      animation: float linear infinite;
    }
    @keyframes float {
      0%   { transform: translateY(100vh) scale(0); opacity: 0; }
      10%  { opacity: 1; }
      90%  { opacity: 0.6; }
      100% { transform: translateY(-20vh) scale(1.2); opacity: 0; }
    }

    /* ── 主容器 ── */
    .container {
      position: relative;
      z-index: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100%;
      padding: 24px;
    }

    /* ── 步骤指示器 ── */
    .steps {
      display: flex;
      gap: 10px;
      margin-bottom: 40px;
      opacity: 0;
      animation: fadein 0.6s ease 0.5s forwards;
    }
    .step-dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #21262d;
      border: 1px solid #30363d;
      transition: all 0.3s ease;
    }
    .step-dot.active {
      background: #1d6fa4;
      border-color: #1d6fa4;
      box-shadow: 0 0 8px rgba(29, 111, 164, 0.6);
    }
    .step-dot.done {
      background: #1abc9c;
      border-color: #1abc9c;
    }

    /* ── 内容卡片 ── */
    .card {
      width: 100%;
      max-width: 680px;
      background: linear-gradient(145deg, #131b28 0%, #0f1520 100%);
      border: 1px solid #21262d;
      border-radius: 20px;
      padding: 48px 52px;
      box-shadow:
        0 0 0 1px rgba(29, 111, 164, 0.1),
        0 24px 64px rgba(0, 0, 0, 0.6),
        0 0 80px rgba(29, 111, 164, 0.05);
      opacity: 0;
      transform: translateY(24px);
      animation: slideup 0.7s cubic-bezier(0.16, 1, 0.3, 1) 0.2s forwards;
    }
    @keyframes slideup {
      to { opacity: 1; transform: translateY(0); }
    }
    @keyframes fadein {
      to { opacity: 1; }
    }

    /* ── Logo区 ── */
    .logo-area {
      display: flex;
      flex-direction: column;
      align-items: center;
      margin-bottom: 36px;
    }
    .logo-icon {
      width: 80px;
      height: 80px;
      margin-bottom: 16px;
      filter: drop-shadow(0 0 20px rgba(29, 111, 164, 0.5));
      animation: pulse 3s ease-in-out infinite;
    }
    @keyframes pulse {
      0%, 100% { filter: drop-shadow(0 0 20px rgba(29, 111, 164, 0.5)); }
      50%       { filter: drop-shadow(0 0 35px rgba(29, 111, 164, 0.9)); }
    }
    .logo-title {
      font-size: 28px;
      font-weight: 700;
      color: #f0f6fc;
      letter-spacing: 0.02em;
      margin-bottom: 6px;
    }
    .logo-badge {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      padding: 4px 12px;
      background: rgba(26, 188, 156, 0.12);
      border: 1px solid rgba(26, 188, 156, 0.3);
      border-radius: 20px;
      font-size: 12px;
      color: #1abc9c;
      font-weight: 500;
    }
    .badge-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
      background: #1abc9c;
      animation: blink 1.5s ease-in-out infinite;
    }
    @keyframes blink {
      0%, 100% { opacity: 1; }
      50%       { opacity: 0.3; }
    }

    /* ── 介绍文字 ── */
    .intro-title {
      font-size: 22px;
      font-weight: 700;
      color: #f0f6fc;
      margin-bottom: 20px;
      line-height: 1.4;
    }
    .intro-body {
      font-size: 15px;
      line-height: 1.9;
      color: #8b949e;
    }
    .intro-body strong {
      color: #c9d1d9;
    }
    .intro-body .highlight {
      color: #1d6fa4;
      font-weight: 600;
    }

    /* ── 特性列表 ── */
    .features {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 12px;
      margin: 24px 0;
    }
    .feature-item {
      display: flex;
      align-items: flex-start;
      gap: 10px;
      padding: 14px 16px;
      background: rgba(255,255,255,0.02);
      border: 1px solid #21262d;
      border-radius: 12px;
      transition: border-color 0.2s;
    }
    .feature-item:hover {
      border-color: rgba(29, 111, 164, 0.3);
    }
    .feature-icon {
      font-size: 20px;
      line-height: 1;
      flex-shrink: 0;
    }
    .feature-text strong {
      display: block;
      font-size: 13px;
      font-weight: 600;
      color: #e6edf3;
      margin-bottom: 3px;
    }
    .feature-text span {
      font-size: 12px;
      color: #6e7681;
      line-height: 1.4;
    }

    /* ── 警告框 ── */
    .warning-box {
      display: flex;
      gap: 14px;
      padding: 16px 20px;
      background: rgba(210, 153, 34, 0.08);
      border: 1px solid rgba(210, 153, 34, 0.25);
      border-radius: 12px;
      margin: 24px 0;
    }
    .warning-icon { font-size: 22px; flex-shrink: 0; }
    .warning-text {
      font-size: 13px;
      color: #d29922;
      line-height: 1.6;
    }
    .warning-text strong {
      color: #e3b341;
      display: block;
      margin-bottom: 4px;
      font-size: 14px;
    }

    /* ── 条款区 ── */
    .terms-box {
      background: #0d1117;
      border: 1px solid #21262d;
      border-radius: 12px;
      padding: 20px;
      margin-bottom: 20px;
      max-height: 220px;
      overflow-y: auto;
      font-size: 13px;
      line-height: 1.8;
      color: #6e7681;
      scrollbar-width: thin;
      scrollbar-color: #21262d transparent;
    }
    .terms-box::-webkit-scrollbar { width: 4px; }
    .terms-box::-webkit-scrollbar-track { background: transparent; }
    .terms-box::-webkit-scrollbar-thumb { background: #30363d; border-radius: 2px; }
    .terms-box h4 {
      color: #8b949e;
      font-size: 12px;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.08em;
      margin: 0 0 10px;
    }
    .terms-box p { margin: 0 0 12px; }
    .terms-box p:last-child { margin: 0; }

    .checkbox-row {
      display: flex;
      align-items: center;
      gap: 10px;
      cursor: pointer;
      user-select: none;
      margin-bottom: 24px;
    }
    .checkbox-row input[type="checkbox"] {
      width: 18px;
      height: 18px;
      accent-color: #1d6fa4;
      cursor: pointer;
    }
    .checkbox-row span {
      font-size: 14px;
      color: #8b949e;
    }
    .checkbox-row span strong {
      color: #c9d1d9;
    }

    /* ── 按钮 ── */
    .btn-row {
      display: flex;
      gap: 12px;
      justify-content: flex-end;
    }
    .btn {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 12px 28px;
      border: none;
      border-radius: 10px;
      font-size: 15px;
      font-weight: 600;
      font-family: inherit;
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .btn-ghost {
      background: transparent;
      border: 1px solid #30363d;
      color: #6e7681;
    }
    .btn-ghost:hover {
      border-color: #484f58;
      color: #8b949e;
    }
    .btn-primary {
      background: linear-gradient(135deg, #1d6fa4 0%, #1557840 100%);
      background: #1d6fa4;
      color: #fff;
      box-shadow: 0 4px 16px rgba(29, 111, 164, 0.3);
    }
    .btn-primary:hover:not(:disabled) {
      background: #2889c8;
      box-shadow: 0 6px 24px rgba(29, 111, 164, 0.5);
      transform: translateY(-1px);
    }
    .btn-primary:disabled {
      background: #21262d;
      color: #484f58;
      box-shadow: none;
      cursor: not-allowed;
    }
    .btn-success {
      background: #1abc9c;
      color: #fff;
      box-shadow: 0 4px 16px rgba(26, 188, 156, 0.3);
    }
    .btn-success:hover {
      background: #17a589;
      transform: translateY(-1px);
    }

    /* ── 完成页 ── */
    .done-area {
      text-align: center;
    }
    .done-icon {
      font-size: 72px;
      margin-bottom: 16px;
      display: block;
      animation: bounce 0.6s cubic-bezier(0.34, 1.56, 0.64, 1) forwards;
    }
    @keyframes bounce {
      from { transform: scale(0); opacity: 0; }
      to   { transform: scale(1); opacity: 1; }
    }
    .done-title {
      font-size: 24px;
      font-weight: 700;
      color: #f0f6fc;
      margin-bottom: 12px;
    }
    .done-sub {
      font-size: 14px;
      color: #6e7681;
      margin-bottom: 32px;
      line-height: 1.7;
    }
    .done-sub strong { color: #c9d1d9; }

    /* ── 底部版权 ── */
    .footer {
      margin-top: 28px;
      font-size: 12px;
      color: #484f58;
      text-align: center;
      opacity: 0;
      animation: fadein 0.6s ease 0.8s forwards;
    }

    /* ── 过渡动画 ── */
    .slide-enter {
      animation: slideenter 0.5s cubic-bezier(0.16, 1, 0.3, 1) forwards;
    }
    @keyframes slideenter {
      from { opacity: 0; transform: translateX(30px); }
      to   { opacity: 1; transform: translateX(0); }
    }
  `;

  private _dots() {
    const dots = [];
    for (let i = 0; i < 18; i++) {
      const size = Math.random() * 120 + 40;
      const left = Math.random() * 100;
      const delay = Math.random() * 12;
      const duration = Math.random() * 15 + 10;
      dots.push(html`
        <div class="bg-dot" style="
          width:${size}px; height:${size}px;
          left:${left}%;
          animation-delay:${delay}s;
          animation-duration:${duration}s;
        "></div>
      `);
    }
    return dots;
  }

  private _logo() {
    return html`
      <svg class="logo-icon" viewBox="0 0 120 120" fill="none" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="wg1" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#1d6fa4"/>
            <stop offset="100%" stop-color="#0d3d6b"/>
          </linearGradient>
          <linearGradient id="wg2" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#1abc9c"/>
            <stop offset="100%" stop-color="#1d6fa4"/>
          </linearGradient>
        </defs>
        <circle cx="60" cy="60" r="56" fill="url(#wg1)"/>
        <path d="M60 18 L60 75 L28 62 Z" fill="white" opacity="0.95"/>
        <path d="M60 25 L60 75 L92 55 Z" fill="white" opacity="0.75"/>
        <path d="M25 78 Q60 92 95 78 L90 86 Q60 98 30 86 Z" fill="white" opacity="0.9"/>
        <path d="M15 95 Q30 90 45 95 Q60 100 75 95 Q90 90 105 95"
          stroke="url(#wg2)" stroke-width="3" stroke-linecap="round" fill="none" opacity="0.8"/>
        <circle cx="60" cy="60" r="4" fill="#1abc9c" opacity="0.9"/>
      </svg>
    `;
  }

  // ── Step 0：欢迎封面 ──────────────────────────────
  private _renderStep0() {
    return html`
      <div class="logo-area">
        ${this._logo()}
        <div class="logo-title">舟岱自动化小助手</div>
        <div class="logo-badge">
          <span class="badge-dot"></span>
          内测版本 · Beta
        </div>
      </div>

      <div class="intro-body" style="text-align:center; margin-bottom:32px;">
        <strong>欢迎使用舟岱自动化小助手</strong><br/>
        由 <span class="highlight">舟岱收费中心</span> 倾力打造的智能桌面代理平台<br/>
        点击「开始了解」，进入产品介绍
      </div>

      <div class="btn-row" style="justify-content:center;">
        <button class="btn btn-primary" @click=${() => this._nextStep()}>
          开始了解 →
        </button>
      </div>
    `;
  }

  // ── Step 1：产品介绍 ──────────────────────────────
  private _renderStep1() {
    return html`
      <div class="slide-enter">
        <div class="intro-title">这是一款什么样的产品？</div>
        <div class="intro-body">
          <strong>舟岱自动化小助手</strong> 是由
          <span class="highlight">舟岱收费中心</span>
          自主研发的<strong>智能桌面自动化代理系统</strong>。
          它不只是一个聊天机器人——它拥有<strong>极高的系统权限</strong>，
          可以直接操控您的桌面、文件、应用程序，替您完成各类复杂任务。
        </div>

        <div class="features">
          <div class="feature-item">
            <div class="feature-icon">🖥️</div>
            <div class="feature-text">
              <strong>全桌面掌控</strong>
              <span>操作任意应用、文件、浏览器，执行完整的桌面工作流</span>
            </div>
          </div>
          <div class="feature-item">
            <div class="feature-icon">🧠</div>
            <div class="feature-text">
              <strong>本地记忆引擎</strong>
              <span>所有知识、习惯、上下文安全存储于本地，永不上传云端</span>
            </div>
          </div>
          <div class="feature-item">
            <div class="feature-icon">📈</div>
            <div class="feature-text">
              <strong>越用越聪明</strong>
              <span>随着使用积累，助手会自我迭代升级，越来越懂你</span>
            </div>
          </div>
          <div class="feature-item">
            <div class="feature-icon">🔒</div>
            <div class="feature-text">
              <strong>数据绝对私密</strong>
              <span>离线部署，所有数据留存本地，无任何隐私泄露风险</span>
            </div>
          </div>
        </div>

        <div class="btn-row">
          <button class="btn btn-ghost" @click=${() => this._prevStep()}>← 返回</button>
          <button class="btn btn-primary" @click=${() => this._nextStep()}>下一步 →</button>
        </div>
      </div>
    `;
  }

  // ── Step 2：条款确认 ──────────────────────────────
  private _renderStep2() {
    return html`
      <div class="slide-enter">
        <div class="intro-title">使用须知 · 测试版声明</div>

        <div class="warning-box">
          <div class="warning-icon">⚠️</div>
          <div class="warning-text">
            <strong>当前版本处于内部测试阶段</strong>
            本版本仅供内部测试使用，功能持续迭代优化中。
            正式商业版本即将发布，届时将提供更稳定、更完整的功能体验。
            测试期间如遇问题，请及时向舟岱团队反馈。
          </div>
        </div>

        <div class="terms-box">
          <h4>使用条款与注意事项</h4>
          <p>
            <strong style="color:#8b949e">1. 权限说明</strong><br/>
            本软件在运行期间将请求对您计算机的操作权限，包括但不限于：文件系统读写、应用程序启动与控制、
            屏幕截图与分析。这些权限是实现自动化功能的必要前提，请您知悉并授权。
          </p>
          <p>
            <strong style="color:#8b949e">2. 数据安全</strong><br/>
            本系统采用完全本地化部署方案。您的所有对话记录、操作日志、个人配置均
            存储于您本地设备，不会上传至任何远程服务器（AI 接口调用除外）。
          </p>
          <p>
            <strong style="color:#8b949e">3. 测试版限制</strong><br/>
            当前版本为内部测试版本，仅限舟岱内部员工及授权测试人员使用。
            禁止将本软件或其相关内容对外传播、分发或商业化使用。
          </p>
          <p>
            <strong style="color:#8b949e">4. 免责声明</strong><br/>
            测试版本可能存在功能缺陷或不稳定情况，舟岱收费中心对测试期间因软件问题
            造成的损失不承担责任。请在重要操作前做好数据备份。
          </p>
          <p>
            <strong style="color:#8b949e">5. 知识产权</strong><br/>
            本软件的设计、代码及所有相关资产均属于舟岱收费中心所有，
            基于 OpenClaw 开源项目（MIT 许可证）构建，保留所有权利。
          </p>
        </div>

        <label class="checkbox-row" @click=${() => { this.checked = !this.checked; }}>
          <input type="checkbox" .checked=${this.checked} @change=${(e: Event) => {
            this.checked = (e.target as HTMLInputElement).checked;
          }} />
          <span>我已阅读并同意上述<strong>使用条款与注意事项</strong>，了解当前为测试版本</span>
        </label>

        <div class="btn-row">
          <button class="btn btn-ghost" @click=${() => this._prevStep()}>← 返回</button>
          <button
            class="btn btn-primary"
            ?disabled=${!this.checked}
            @click=${() => this._nextStep()}
          >
            接受并继续 →
          </button>
        </div>
      </div>
    `;
  }

  // ── Step 3：完成 ──────────────────────────────────
  private _renderStep3() {
    return html`
      <div class="slide-enter done-area">
        <span class="done-icon">🚀</span>
        <div class="done-title">一切就绪，欢迎登船！</div>
        <div class="done-sub">
          <strong>舟岱自动化小助手</strong> 已准备好为您服务<br/>
          连接网关后即可开始使用全部功能<br/>
          <br/>
          如需帮助，请联系 <strong>舟岱收费中心技术团队</strong>
        </div>
        <button class="btn btn-success" @click=${() => this._finish()}>
          ✦ 进入控制台
        </button>
      </div>
    `;
  }

  private _nextStep() {
    this.animating = true;
    setTimeout(() => {
      this.step = Math.min(this.step + 1, 3);
      this.animating = false;
    }, 50);
  }

  private _prevStep() {
    this.step = Math.max(this.step - 1, 0);
  }

  private _finish() {
    if (this.onAccept) {
      this.onAccept();
    }
  }

  render() {
    const stepContent = [
      this._renderStep0(),
      this._renderStep1(),
      this._renderStep2(),
      this._renderStep3(),
    ][this.step];

    const stepLabels = ["欢迎", "介绍", "条款", "完成"];

    return html`
      <!-- 动态粒子背景 -->
      <div class="bg-canvas">${this._dots()}</div>

      <div class="container">
        <!-- 步骤指示器 -->
        <div class="steps">
          ${stepLabels.map((_, i) => html`
            <div class="step-dot ${i < this.step ? "done" : i === this.step ? "active" : ""}"></div>
          `)}
        </div>

        <!-- 内容卡片 -->
        <div class="card">
          ${stepContent}
        </div>

        <!-- 底部 -->
        <div class="footer">
          © 2026 舟岱收费中心 · 舟岱自动化小助手 Beta &nbsp;·&nbsp; 保留所有权利
        </div>
      </div>
    `;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    "zhoudai-welcome": ZhoudaiWelcome;
  }
}
