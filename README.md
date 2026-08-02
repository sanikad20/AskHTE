# 🏛️ AskHTE: AI-Powered Question Answering System
> **Department of Higher & Technical Education (HTE), Government of Maharashtra**  


> *"Ask Official Documents. Get Cited, Trusted Answers."*

[![Flutter](https://img.shields.io/badge/Frontend-Flutter_3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/Backend-FastAPI_0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![ChromaDB](https://img.shields.io/badge/Vector_DB-ChromaDB-FF6F00)](https://www.trychroma.com)
[![SentenceTransformers](https://img.shields.io/badge/Embeddings-Local_MiniLM_L6-blue)](https://www.sbert.net)
[![Groq LLM](https://img.shields.io/badge/LLM-Llama_3.3_70B_Groq-f50057)](https://groq.com)

---

## 📌 Overview

**AskHTE** is an enterprise-grade, AI-powered administrative decision support and Question Answering (QA) system designed specifically for the **Higher & Technical Education (HTE) Department, Government of Maharashtra**.

The system enables government officials, administrators, institute heads, and students to query complex Government Resolutions (GRs), Circulars, and Policy Directives in natural language (English, Marathi, and Hindi) and receive instant, source-grounded answers backed by exact page citations and confidence scores.

---

## ⭐ Key Capabilities & Features

### 1. 🛡️ Accurate, Source-Grounded Answers (Zero Hallucination)
- Powered by a local **Retrieval-Augmented Generation (RAG)** pipeline.
- Answers are generated strictly from ingested official government PDF documents.
- If a queried fact is missing from the corpus, the system explicitly states: *"Information unavailable in authenticated government documents."*

### 2. 🌐 Trilingual AI Engine (English • Marathi • Hindi)
- Supports queries and responses in **English**, **Marathi (मराठी)**, and **Hindi (हिंदी)**.
- Features automatic query language detection and preserves official administrative terminology (e.g. GR numbers, section codes, desk officer names) during translation.
- Includes Devanagari **Unicode NFC Normalization** (`unicodedata.normalize('NFC')`) to eliminate rendering glitches and dotted circles (`◌`).

### 3. 📄 Page-Level Citations & Confidence Score
- Every generated response features:
  - Exact **Source Document Name** & **GR/Circular Reference Number**.
  - **Page Number Citations** e.g. `[1] GR-2024/12.pdf (Page 3)`.
  - **Clickable Reference Chips**: Tapping opens a preview sheet showing the original document metadata and page location.
  - **Visual Confidence Indicator**: Color-coded score (85%–98% high green confidence).

### 4. 📝 Intelligent Document Summarization
- Generates structured executive summaries of lengthy government circulars.
- Outputs:
  - **Executive Summary** (Concise 3–4 sentences or Detailed 6–8 sentences).
  - **Key Bullet Points** (3–5 key policy mandates).
  - **Effective Date** & **Target Applicability** (Institutes, Students, Faculty).
  - **Issuing Authority** (Department / Directorates).

### 5. ⚖️ Side-by-Side Document Clause Comparison
- Compares two circulars or GR versions to highlight administrative updates:
  - 🟢 **Added Clauses**: New provisions introduced in the newer circular.
  - 🔴 **Removed / Superseded Clauses**: Legacy conditions omitted or replaced.
  - 🟡 **Modified Provisions**: Updated deadlines, fee structures, or eligibility criteria.
  - 💡 **Administrative Policy Differences**: High-level policy scope shifts.

### 6. 🕸️ Administrative Knowledge Graph & Conflict Detection
- Extracts reference numbers (`Circular No.`, `GR No.`), personnel cues (`Registrar`, `Director`, `Desk Officer`), and dates.
- Maps inter-document relationships (*supersedes*, *amends*, *extends*, *cancels*).
- Flags conflicting deadline dates across unlinked circular versions.

### 7. ⚡ Memory-Bounded Production Engine (512MB RAM Bounded)
- Custom internal batching (`BATCH_SIZE = 8`) and active garbage collection (`gc.collect()`) ensure zero OOM crashes during PDF OCR and embedding on low-cost cloud instances (e.g., Render Free Tier).

---

## 🏗️ Architecture & Tech Stack

```
 📱 Flutter Mobile / Web App (Material 3 Dark/Light UI, Google Fonts Noto Sans Devanagari)
                          │
                          ▼  (REST API / JSON)
 🚀 FastAPI Backend Gateway (Python 3.11)
                          │
   ┌──────────────────────┼────────────────────────┐
   ▼                      ▼                        ▼
📄 PyMuPDF + Tesseract  🧠 Local SentenceTransformers  🗄️ ChromaDB Vector Store
   (PDF Text & OCR)        (multi-qa-MiniLM-L6-cos-v1)   (384-dim Embeddings)
                          │
                          ▼
             ⚡ Groq Llama 3.3-70B LLM (Source-Grounded Reasoning)
```

### Technology Breakdown
- **Frontend**: Flutter 3.x, Dart, Firebase Firestore (Graph Edges), Google Fonts (`Noto Sans Devanagari`).
- **Backend API**: FastAPI, PyDantic, Uvicorn, Asyncio.
- **Document Processing**: PyMuPDF (`fitz`), PyTesseract (`tesseract-ocr-mar`, `tesseract-ocr-hin`), PIL.
- **Embeddings**: `sentence-transformers/multi-qa-MiniLM-L6-cos-v1` (384-dimensional bi-encoder).
- **Vector Database**: ChromaDB (In-memory persistent HNSW vector index).
- **LLM Reasoning**: Groq API (`llama-3.3-70b-versatile`).

---

## 📁 Repository Directory Structure

```
AskHTE_v5/
├── askhte_v5/
│   ├── atlasai_app/                    # Flutter Mobile Application
│   │   ├── lib/
│   │   │   ├── main.dart               # App Entrypoint
│   │   │   ├── screens/
│   │   │   │   ├── askhte_home_screen.dart    # Home Screen & "Why AskHTE?" Cards
│   │   │   │   ├── technician/chat_screen.dart # AI Chat & Search Interface
│   │   │   │   └── upload_document_screen.dart # Document Ingestion Screen
│   │   │   ├── services/
│   │   │   │   ├── orchestrator_service.dart   # Backend API Client
│   │   │   │   └── storage_service.dart        # Upload Service
│   │   │   ├── theme/
│   │   │   │   └── app_theme.dart              # Deep Teal Theme & Font Fallbacks
│   │   │   └── widgets/
│   │   │       ├── citation_chips.dart         # Clickable PDF Source Cards
│   │   │       ├── confidence_badge.dart       # Confidence Indicator
│   │   │       └── explainable_ai_panel.dart   # Grounded AI Response Card
│   │   └── pubspec.yaml
│   │
│   └── atlasai_backend/                # FastAPI Backend Server
│       ├── app/
│       │   ├── main.py                 # FastAPI Routes & App Gateway
│       │   ├── orchestrator.py         # Multi-Agent Routing Engine
│       │   ├── agents/
│       │   │   └── knowledge_agent.py  # Grounded RAG QA Agent
│       │   ├── services/
│       │   │   ├── chroma_client.py    # ChromaDB Vector Database Manager
│       │   │   ├── document_relationships.py # Summarization & Comparison Engine
│       │   │   ├── embeddings.py       # Batched Local SentenceTransformers
│       │   │   ├── entity_extraction.py# GR Reference & Date Extraction
│       │   │   ├── ingestion.py        # PDF Page Extractor & Tesseract OCR
│       │   │   ├── language.py         # Trilingual Translation & NFC Normalization
│       │   │   └── retrieval.py        # Cosine Distance & Confidence Rescaling
│       │   └── models/
│       │       └── schemas.py          # Request & Response Schemas
│       └── Dockerfile                  # Production Container Specification
└── README.md
```

---

## 🛠️ Setup & Running Locally

### Prerequisites
- **Python**: 3.10 or 3.11 installed
- **Flutter**: 3.x SDK installed
- **Tesseract OCR**: Installed with Devanagari languages (`tesseract-ocr-mar`, `tesseract-ocr-hin`)

---

### 1. Backend Server Setup

```bash
# 1. Navigate to the backend directory
cd askhte_v5/atlasai_backend

# 2. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate

# 3. Install backend dependencies
pip install -r requirements.txt

# 4. Set environment variables
export GROQ_API_KEY="your_groq_api_key_here"

# 5. Start the FastAPI server
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The backend server will run on `http://localhost:8000`. You can inspect the interactive OpenAPI documentation at `http://localhost:8000/docs`.

---

### 2. Flutter Frontend Setup

```bash
# 1. Navigate to the Flutter app directory
cd askhte_v5/atlasai_app

# 2. Fetch Flutter dependencies
flutter pub get

# 3. Launch the application (Android / Web / Linux)
flutter run
```

---

### 3. Docker Container Build

```bash
cd askhte_v5/atlasai_backend

# Build the Docker image
docker build -t askhte-backend .

# Run the container locally
docker run -d -p 8000:8000 -e GROQ_API_KEY="your_groq_api_key" askhte-backend
```

---

## 📡 API Endpoint Reference

| Endpoint | Method | Description |
|---|---|---|
| `/ping` | `GET` | Health check endpoint returning backend status. |
| `/ingest` | `POST` | Ingests a PDF circular, extracts text/OCR, embeds chunks, and indexes into ChromaDB. |
| `/query` | `POST` | Processes a natural language query, retrieves grounded chunks, and returns cited answer. |
| `/documents/list` | `GET` | Returns list of all ingested government circulars and metadata. |
| `/documents/summarize` | `POST` | Generates a structured executive summary of a specified document. |
| `/documents/compare` | `GET` | Compares two circulars side-by-side highlighting added, removed, and modified clauses. |

---

## 🤝 Key Stakeholders & Credits

- **Department**: Department of Higher & Technical Education, Government of Maharashtra
- **Event**: VJTI AI Hackathon 2026 — Problem Area 3 (AI-Powered Question Answering System)
- **Engine**: AskHTE Core AI Architecture

---

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
