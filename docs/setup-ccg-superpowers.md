# Setup: Superpowers + Tri-Model Advisor (CCG) para Claude Code

Guia para instalar el fork de Superpowers con el skill CCG (Claude-Codex-Gemini) en una nueva Mac.

---

## Prerequisitos

### 1. Claude Code CLI

```bash
npm install -g @anthropic-ai/claude-code
```

Verificar:
```bash
claude --version
```

### 2. Codex CLI (OpenAI)

```bash
npm install -g @openai/codex
```

Requiere API key de OpenAI configurada:
```bash
codex login
# o exportar: export OPENAI_API_KEY=sk-...
```

Verificar:
```bash
codex --version
```

### 3. Gemini CLI (Google)

```bash
npm install -g @google/gemini-cli
```

Requiere autenticacion con Google:
```bash
gemini
# La primera vez te pide login con Google account
```

Verificar:
```bash
gemini --version
```

---

## Instalacion del Fork de Superpowers

### Paso 1: Registrar el marketplace

Editar `~/.claude/settings.json` y agregar dentro de `extraKnownMarketplaces`:

```json
{
  "extraKnownMarketplaces": {
    "superpowers-marketplace": {
      "source": {
        "source": "github",
        "repo": "PabloAraya6/superpowers"
      }
    }
  }
}
```

Si el archivo no existe o esta vacio, crear con esta estructura minima:

```json
{
  "extraKnownMarketplaces": {
    "superpowers-marketplace": {
      "source": {
        "source": "github",
        "repo": "PabloAraya6/superpowers"
      }
    }
  }
}
```

### Paso 2: Instalar el plugin

Abrir Claude Code y ejecutar:

```
/install-plugin superpowers@superpowers-marketplace
```

Claude Code descarga el plugin del fork y lo registra automaticamente.

### Paso 3: Habilitar el plugin

En `~/.claude/settings.json`, agregar en `enabledPlugins`:

```json
{
  "enabledPlugins": {
    "superpowers@superpowers-marketplace": true
  }
}
```

### Paso 4: Verificar

Reiniciar Claude Code y verificar que los skills estan disponibles. Escribir:

```
/ccg Que principio de clean code es mas importante?
```

Deberia:
1. Clasificar el modo (GENERAL)
2. Verificar que codex y gemini estan disponibles
3. Componer dos prompts especializados
4. Correr ambos advisors en paralelo
5. Sintetizar las respuestas con secciones Agreed / Conflicting / Final Direction

---

## Que incluye este fork

### Skills de Superpowers (originales de obra/superpowers)

- `brainstorming` — divergent thinking estructurado
- `systematic-debugging` — root cause analysis con proceso
- `test-driven-development` — TDD disciplinado
- `writing-plans` — planes de implementacion
- `executing-plans` — ejecucion de planes
- `subagent-driven-development` — orquestacion multi-agente
- `verification-before-completion` — quality gates
- `dispatching-parallel-agents` — paralelizacion
- Y mas...

### Skill custom: tri-model-advisor (CCG)

Orquestacion tri-modelo: Claude + Codex + Gemini.

**Modos:**

| Modo | Cuando usarlo |
|---|---|
| REVIEW | Code review o PR review |
| ARCHITECTURE | Decisiones de diseno y trade-offs |
| SECURITY | Vulnerabilidades, auth, datos |
| BRAINSTORM | Alternativas e ideas nuevas |
| GENERAL | Todo lo demas |

**Archivos del skill:**

```
skills/tri-model-advisor/
  SKILL.md              — Protocolo principal
  advisor-prompts.md    — Templates de rol por modo
  debate-protocol.md    — Ronda de debate opcional
  artifact-format.md    — Formato de persistencia
  run-advisor.sh        — Script de orquestacion
```

**Invocacion:**

```
/ccg <tu consulta>
```

---

## Mantenimiento automatico

El fork tiene dos GitHub Actions:

### Sync diario (8:00 UTC)
- Mergea automaticamente cambios de obra/superpowers
- Si hay conflicto, crea un PR para resolver manualmente
- Crea un issue en GitHub cuando hay cambios nuevos (te llega por email)

### Keepalive (lunes 12:00 UTC)
- Chequea si el repo esta cerca del limite de 60 dias de inactividad de GitHub
- Si esta en 50+ dias sin actividad, crea un issue de alerta y hace un commit automatico para resetear el timer
- Garantiza que el sync diario nunca se desactive

---

## Configuracion opcional

### Modelos

Por defecto usa el **modelo tope de gama de cada CLI** automaticamente:
- **Codex**: no se pasa `-m`, usa el default del CLI (se actualiza con `npm update -g @openai/codex`)
- **Gemini**: usa `-m auto`, que siempre resuelve al mejor modelo disponible

Para forzar un modelo especifico:

```bash
# En tu shell profile (~/.zshrc)
export CCG_CODEX_MODEL="o3"         # forzar o3
export CCG_GEMINI_MODEL="flash"     # forzar flash (mas rapido, menos capaz)
```

Para mantenerte siempre en el ultimo modelo: **no setees estas variables** y manten los CLIs actualizados.

### Timeout

```bash
export CCG_TIMEOUT=180  # segundos por advisor (default: 120)
```

---

## Troubleshooting

| Problema | Solucion |
|---|---|
| `codex: MISSING` | `npm install -g @openai/codex` + `codex login` |
| `gemini: MISSING` | `npm install -g @google/gemini-cli` + correr `gemini` una vez para auth |
| Codex falla con "Not inside a trusted directory" | El skill ya usa `--skip-git-repo-check`, verificar version de codex |
| Codex falla con sandbox | Se reintenta automaticamente con `--dangerously-bypass-approvals-and-sandbox` |
| `timeout: command not found` | El script usa fallback automatico para macOS (no necesita `coreutils`) |
| Plugin no aparece | Reiniciar Claude Code. Verificar `settings.json` |
| Sync workflow no corre | Ir a GitHub > Actions > Run workflow manualmente |

---

## Repositorio

Fork: https://github.com/PabloAraya6/superpowers
Upstream: https://github.com/obra/superpowers
