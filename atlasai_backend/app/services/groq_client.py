import os
import httpx

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
DEFAULT_MODEL = "llama-3.3-70b-versatile"


async def chat_completion(system_prompt: str, user_prompt: str, model: str = DEFAULT_MODEL) -> str:
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError("GROQ_API_KEY not set")

    async with httpx.AsyncClient(timeout=30.0) as client:
        res = await client.post(
            GROQ_URL,
            headers={"Authorization": f"Bearer {api_key}"},
            json={
                "model": model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
                "temperature": 0.2,
            },
        )
        res.raise_for_status()
        data = res.json()
        return data["choices"][0]["message"]["content"]
