# AskHTE — AI-Powered Question Answering System for the HTE Department

**VJTI AI Hackathon 2026 · Problem Area 3 — AI-Powered Question Answering System for Higher & Technical Education (HTE) Department**

> "Ask Official Documents. Get Cited, Trusted Answers."

AskHTE is an AI-powered administrative assistant built for the Higher and Technical Education (HTE) Department, Maharashtra Government. It enables department staff, institute administrators, faculty, and students to quickly retrieve information from official circulars, Government Resolutions (GRs), notices, and policy documents.

Answers are strictly grounded in authenticated government documents using **Retrieval-Augmented Generation (RAG)**, vector embeddings, and LLM synthesis.

---

## 🌟 Key Features Implemented

### 1. 🌐 Multilingual Support (English • Marathi • Hindi)
- Accepts queries in **English**, **मराठी (Marathi)**, and **हिंदी (Hindi)**.
- Automatic language detection and user-controlled response language switcher.
- Preserves official Indian Government terminology (e.g. GR numbers, circular numbers, CAP round, scheme titles, DTE guidelines) during translation.

### 2. 📌 Source Citations & Confidence Scores
- Every AI-generated answer displays:
  - Source document name
  - Relevant GR/Circular number
  - Page & section numbers
  - RAG confidence score percentage (`99.4%`)
- **Clickable Citations**: Tap any source chip to open and verify the authenticated government document passage.

### 3. 📄 Document Summarization
- On-demand summary generation for any ingested government circular or resolution.
- Supports both **Concise** (3-4 sentence) and **Detailed** (comprehensive) depth.
- Automatically extracts **Key Bullet Points**, **Effective Date**, **Applicability**, and **Issuing Authority**.

### 4. ⚖️ Document Comparison & Clause Diffing
- Compares any two Government Resolutions or circulars side-by-side.
- Highlights:
  - ➕ **Added Clauses** (new provisions introduced)
  - ➖ **Removed Clauses** (superseded legacy conditions)
  - ✏️ **Modified Provisions** (updated timelines and guidelines)
  - 💡 **Policy Differences** (structural administrative updates)

### 5. 🔒 Authenticated Government Document Retrieval
- Answers are generated **ONLY** from authenticated government documents stored in the ChromaDB knowledge base.
- If sufficient information is unavailable in the ingested documents, AskHTE returns a clear message: `"Information unavailable in authenticated government documents."` preventing hallucination.

### 6. 🏛️ AI-Assisted Administrative Decision Support
- Provides actionable administrative recommendations under answers.
- Suggests related Government Resolutions, circulars, and departmental compliance directives.

### 7. 🏷️ Enhanced Chat & Badging System
- Displays visual trust badges on answers:
  - `🔒 Verified Source`
  - `⚡ RAG Powered`
  - `Confidence Score`
  - `Language (EN/MR/HI)`

---

## 🏗️ System Architecture

```text
               Official HTE Documents (PDFs / GRs / Circulars)
                                      |
                                      v
                    Document Ingestion & Chunking
                                      |
                                      v
                      Chroma Vector Store + Knowledge Graph
                                      |
                                      v
          Multilingual Translation & Semantic Vector Search
                                      |
                                      v
                        Groq (Llama 3.3 70B Engine)
                                      |
                                      v
         Grounded Answer + Citations + Administrative Recommendations
                                      |
                                      v
                       AskHTE Flutter Client & API
```

---

## 🛠️ Tech Stack

### 🎨 Frontend (`atlasai_app`)
- **Framework**: Flutter (Dart)
- **Theme**: Obsidian Cyberpunk Dark Theme with Purple Neon Accents
- **Features**: Voice Input (Speech-to-Text), Multilingual Switcher, Document Summarizer Modal, Document Comparison Modal, Clickable Citation Chips

### ⚙️ Backend (`atlasai_backend`)
- **Framework**: FastAPI (Python)
- **AI/ML Engine**: Groq (Llama 3.3 70B)
- **Vector DB**: ChromaDB
- **Embeddings**: `sentence-transformers/multi-qa-MiniLM-L6-cos-v1`
- **Services**:
  - `language.py`: Multilingual detection, query translation, and term-preserving response translation
  - `retrieval.py`: Semantic vector retrieval & confidence scoring
  - `document_relationships.py`: Graph analysis, timeline building, conflict detection, LLM clause diffing, & summarization

---

## 🔌 API Endpoints Summary

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/ping` | Health check endpoint |
| `POST` | `/query` | Main RAG Q&A endpoint (supports `target_language`, `equipment_id`) |
| `POST` | `/ingest` | Upload & ingest government PDF documents |
| `GET` | `/documents/list` | List all ingested government documents |
| `POST` | `/documents/summarize` | Summarize document (`short` or `detailed`) |
| `GET` | `/documents/compare` | Compare 2 circulars & return clause diffs |
| `GET` | `/documents/graph` | Document relationship graph, timeline, and conflict analysis |

---

## 🚀 Getting Started

### 1. Run the Backend API
```bash
cd atlasai_backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### 2. Run the Flutter App
```bash
cd atlasai_app
flutter pub get
flutter run -d chrome   # Or: flutter run -d linux
```
