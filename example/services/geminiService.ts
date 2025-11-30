
import { GoogleGenAI, Type, Schema } from "@google/genai";
import { GeneratedEnemyData, GeneratedLootData, EquipmentSlot } from "../types";

// Initialize Gemini Client
const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

const enemySchema: Schema = {
  type: Type.OBJECT,
  properties: {
    name: { type: Type.STRING, description: "Nome do inimigo de RPG de fantasia em Português (ex: Slime Ácido, Caranguejo de Pedra, Observador)" },
    description: { type: Type.STRING, description: "Uma descrição curta e engraçada do inimigo em Português." },
    maxHp: { type: Type.INTEGER, description: "Pontos de vida (entre 50 e 200 dependendo da dificuldade)" },
    attack: { type: Type.INTEGER, description: "Poder de ataque (entre 5 e 20)" },
    defense: { type: Type.INTEGER, description: "Poder de defesa (entre 0 e 10)" },
    isBoss: { type: Type.BOOLEAN, description: "Se este inimigo é um chefe" },
    visualPrompt: { type: Type.STRING, description: "Uma palavra-chave visual (ex: 'slime', 'crab', 'eye', 'dragon')" }
  },
  required: ["name", "description", "maxHp", "attack", "defense", "isBoss", "visualPrompt"],
};

const lootSchema: Schema = {
  type: Type.OBJECT,
  properties: {
    name: { type: Type.STRING, description: "Nome do item de RPG em Português (ex: Botas de Mithril, Anel de Rubi)" },
    type: { type: Type.STRING, enum: ["BOOTS", "ACCESSORY", "HELMET", "ARMOR", "PANTS", "GLOVES"] },
    statBoost: { type: Type.INTEGER, description: "A quantidade numérica que este item aumenta os status (3-15)" },
    description: { type: Type.STRING, description: "Texto curto de descrição em Português." }
  },
  required: ["name", "type", "statBoost", "description"]
};

export const generateEnemy = async (level: number): Promise<GeneratedEnemyData> => {
  const modelId = "gemini-2.5-flash"; 
  
  const difficultyMultiplier = 1 + (level * 0.2);
  
  const prompt = `
    Gere um novo inimigo para um RPG de Fantasia. 
    O nível atual do jogador é ${level}.
    Crie um inimigo com tema criativo (ex: variações de Slimes, Crustáceos, Olhos Voadores ou Goblins).
    Responda APENAS em Português do Brasil.
    HP deve ser aproximadamente ${50 * difficultyMultiplier}.
    Ataque deve ser aproximadamente ${8 * difficultyMultiplier}.
  `;

  try {
    const response = await ai.models.generateContent({
      model: modelId,
      contents: prompt,
      config: {
        responseMimeType: "application/json",
        responseSchema: enemySchema,
        temperature: 0.8,
      },
    });

    const text = response.text;
    if (!text) throw new Error("No response from Gemini");
    
    return JSON.parse(text) as GeneratedEnemyData;
  } catch (error) {
    console.error("Gemini Enemy Gen Error:", error);
    return {
      name: "Slime Genérico",
      description: "Um slime verde padrão. Não muito ameaçador.",
      maxHp: 50,
      attack: 5,
      defense: 0,
      isBoss: false,
      visualPrompt: "slime"
    };
  }
};

export const generateLoot = async (level: number): Promise<GeneratedLootData> => {
  const modelId = "gemini-2.5-flash";
  const prompt = `
    Gere um item de recompensa por vencer um CHEFE nível ${level} em um RPG de Fantasia.
    Pode ser Bota (Boots), Acessório, Capacete, Armadura, Calça ou Luva.
    Faça parecer Épico e Poderoso. Responda em Português.
    O aumento de status deve ser entre 5 e 20.
  `;

  try {
     const response = await ai.models.generateContent({
      model: modelId,
      contents: prompt,
      config: {
        responseMimeType: "application/json",
        responseSchema: lootSchema,
      },
    });
    const text = response.text;
    return JSON.parse(text!) as GeneratedLootData;
  } catch (e) {
    return {
      name: "Artefato Antigo",
      type: "ACCESSORY",
      statBoost: 5,
      description: "Um item misterioso encontrado no escuro."
    };
  }
};

// New FAST local generator to avoid waiting for AI on every mob
export const generateFastLoot = (level: number): GeneratedLootData => {
  // 5% chance for a 1-UP
  if (Math.random() > 0.95) {
    return {
      name: "COGUMELO VIDA",
      type: "LIFE",
      statBoost: 1,
      description: "Garante uma vida extra!"
    };
  }

  const materials = ["Couro", "Ferro", "Aço", "Mithril", "Ouro", "Diamante"];
  const material = materials[Math.min(materials.length - 1, Math.floor(level / 3))] || "Cósmico";
  
  const slots: EquipmentSlot[] = ['BOOTS', 'HELMET', 'ARMOR', 'PANTS', 'GLOVES', 'ACCESSORY'];
  const type = slots[Math.floor(Math.random() * slots.length)];

  let name = "";
  if (type === 'BOOTS') name = `Botas de ${material}`;
  if (type === 'HELMET') name = `Capacete de ${material}`;
  if (type === 'ARMOR') name = `Peitoral de ${material}`;
  if (type === 'PANTS') name = `Calças de ${material}`;
  if (type === 'GLOVES') name = `Luvas de ${material}`;
  if (type === 'ACCESSORY') name = `Anel de ${material}`;

  const baseStat = Math.max(1, Math.floor(level / 2));
  const variation = Math.floor(Math.random() * 3);

  return {
    name: name,
    type: type,
    statBoost: baseStat + variation,
    description: `Um item feito de ${material.toLowerCase()}.`
  };
};