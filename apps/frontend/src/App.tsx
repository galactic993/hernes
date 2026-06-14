import { AuthArea } from './auth/AuthArea'
import { ProdQuoteTop } from './features/prod-quote/ProdQuoteTop'

export function App() {
  return (
    <main>
      <header>
        <h1>制作見積書作成 &lt;トップ画面&gt;</h1>
        <AuthArea />
      </header>
      <ProdQuoteTop />
    </main>
  )
}
