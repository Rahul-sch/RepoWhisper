"""
Boss Mode Advisor
Generates talking points from transcript, screenshot, and code snippets.
"""

import os
import base64
from typing import Optional
from io import BytesIO
from dataclasses import dataclass

from PIL import Image
import openai
from config import get_settings


@dataclass
class AdvisorContext:
    """Context for generating talking points."""
    transcript: str
    screenshot_base64: Optional[str] = None
    code_snippets: list[str] = None
    meeting_context: Optional[str] = None


@dataclass
class TalkingPoint:
    """A generated talking point."""
    text: str
    confidence: float
    context: str  # Which part triggered this (transcript/screenshot/code)


class BossModeAdvisor:
    """Generates intelligent talking points for meetings."""
    
    def __init__(self):
        self.settings = get_settings()
        # Initialize OpenAI client (can use API key from env)
        api_key = os.getenv("OPENAI_API_KEY", "")
        if api_key:
            self.client = openai.OpenAI(api_key=api_key)
        else:
            self.client = None
    
    def generate_talking_point(
        self,
        context: AdvisorContext
    ) -> TalkingPoint:
        """
        Generate a talking point from context.
        
        Args:
            context: AdvisorContext with transcript, screenshot, code snippets
            
        Returns:
            TalkingPoint with suggested response
        """
        if not self.client:
            # Fallback: simple rule-based response
            return self._fallback_talking_point(context)
        
        try:
            # Build prompt
            prompt = self._build_prompt(context)
            
            # Prepare messages
            messages = [
                {
                    "role": "system",
                    "content": "You are a helpful coding assistant. Generate a concise, professional talking point (1-2 sentences) that the user can say in a meeting to sound knowledgeable. Focus on technical insights from the code or discussion."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ]
            
            # Prepare vision input if screenshot available
            if context.screenshot_base64:
                messages[1]["content"] = [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{context.screenshot_base64}"
                        }
                    }
                ]
            
            # Call OpenAI API
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",  # Fast and cheap
                messages=messages,
                max_tokens=150,
                temperature=0.7
            )
            
            talking_point_text = response.choices[0].message.content.strip()
            
            return TalkingPoint(
                text=talking_point_text,
                confidence=0.9,
                context="ai_generated"
            )
            
        except Exception as e:
            # Fallback on error
            return self._fallback_talking_point(context)
    
    def _build_prompt(self, context: AdvisorContext) -> str:
        """Build the prompt for the LLM."""
        prompt_parts = []
        
        if context.transcript:
            prompt_parts.append(f"Recent discussion:\n{context.transcript}")
        
        if context.code_snippets:
            code_text = "\n\n".join(context.code_snippets[:3])  # Limit to 3 snippets
            prompt_parts.append(f"Relevant code:\n{code_text}")
        
        if context.meeting_context:
            prompt_parts.append(f"Meeting context: {context.meeting_context}")
        
        prompt_parts.append(
            "\nGenerate a concise talking point (1-2 sentences) the user can say to contribute meaningfully to this discussion."
        )
        
        return "\n\n".join(prompt_parts)
    
    def _fallback_talking_point(self, context: AdvisorContext) -> TalkingPoint:
        """Fallback rule-based talking point generator."""
        transcript_lower = context.transcript.lower()
        
        # Simple keyword matching
        if any(word in transcript_lower for word in ["error", "bug", "issue", "problem"]):
            return TalkingPoint(
                text="I can help debug that. Let me check the error handling in our codebase.",
                confidence=0.6,
                context="transcript_keyword"
            )
        
        if any(word in transcript_lower for word in ["performance", "slow", "optimize"]):
            return TalkingPoint(
                text="We should profile that. I can look at optimization opportunities in the code.",
                confidence=0.6,
                context="transcript_keyword"
            )
        
        if context.code_snippets:
            return TalkingPoint(
                text="Based on the code structure, I think we should consider refactoring this for better maintainability.",
                confidence=0.5,
                context="code_snippets"
            )
        
        # Default
        return TalkingPoint(
            text="That's a good point. Let me review the implementation details and get back to you.",
            confidence=0.4,
            context="default"
        )


# Global advisor instance
_advisor: Optional[BossModeAdvisor] = None


def get_advisor() -> BossModeAdvisor:
    """Get the global advisor instance."""
    global _advisor
    if _advisor is None:
        _advisor = BossModeAdvisor()
    return _advisor


def process_screenshot(screenshot_data: bytes) -> str:
    """
    Process screenshot and return base64 string.
    
    Args:
        screenshot_data: Raw image bytes (JPEG/PNG)
        
    Returns:
        Base64-encoded image string
    """
    try:
        # Open and validate image
        image = Image.open(BytesIO(screenshot_data))
        
        # Resize if too large (max 1024px width for API efficiency)
        max_width = 1024
        if image.width > max_width:
            ratio = max_width / image.width
            new_height = int(image.height * ratio)
            image = image.resize((max_width, new_height), Image.Resampling.LANCZOS)
        
        # Convert to JPEG for smaller size
        output = BytesIO()
        image.convert("RGB").save(output, format="JPEG", quality=85)
        output.seek(0)
        
        # Encode to base64
        return base64.b64encode(output.read()).decode("utf-8")
        
    except Exception as e:
        raise ValueError(f"Failed to process screenshot: {str(e)}")

