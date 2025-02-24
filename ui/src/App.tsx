import { useEffect, useState } from "react";
import { Star, StarOff } from "lucide-react";
import { Toaster, toast } from "react-hot-toast";

interface Image {
  id: string;
  url: string;
}

function App() {
  const [currentImage, setCurrentImage] = useState<Image | null>(null);
  const [rating, setRating] = useState<number>(0);
  const [loading, setLoading] = useState(false);

  const loadNextImage = async () => {
    try {
      setLoading(true);
      const response = await fetch("/api/images/next");
      console.log(response);
      if (!response.ok) {
        throw new Error("Failed to load next image");
      }
      const data = await response.json();
      setCurrentImage(data);
      setRating(0);
    } catch (error) {
      toast.error("Failed to load next image");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadNextImage();
  }, []);

  const handleVote = async () => {
    if (!currentImage || rating === 0) {
      toast.error("Please select a rating");
      return;
    }

    try {
      const response = await fetch("/api/votes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ image_id: currentImage.id, rating }),
      });

      if (!response.ok) throw new Error("Failed to submit vote");

      toast.success("Vote recorded");
      loadNextImage();
    } catch (error) {
      toast.error("Failed to submit vote");
    }
  };

  return (
    <div className="min-h-screen bg-gray-100 py-8 px-4">
      <div className="max-w-2xl mx-auto">
        <h1 className="text-3xl font-bold text-center mb-8">
          Image Rating App
        </h1>

        <div className="bg-white rounded-lg shadow-md overflow-hidden">
          {currentImage ? (
            <>
              <div className="relative aspect-video">
                <img
                  src={currentImage.url}
                  alt="Vote on this"
                  className="w-full h-full object-cover"
                />
              </div>

              <div className="p-6">
                <div className="flex justify-center gap-2 mb-6">
                  {[1, 2, 3, 4, 5].map((value) => (
                    <button
                      key={value}
                      onClick={() => setRating(value)}
                      className="transition-transform hover:scale-110 focus:outline-none"
                    >
                      {value <= rating ? (
                        <Star className="w-8 h-8 fill-yellow-400 text-yellow-400" />
                      ) : (
                        <StarOff className="w-8 h-8 text-gray-300" />
                      )}
                    </button>
                  ))}
                </div>

                <button
                  onClick={handleVote}
                  disabled={loading || rating === 0}
                  className={`w-full py-3 px-4 rounded-md text-white font-medium ${
                    loading || rating === 0
                      ? "bg-gray-400 cursor-not-allowed"
                      : "bg-blue-500 hover:bg-blue-600"
                  }`}
                >
                  Submit Vote
                </button>
              </div>
            </>
          ) : (
            <div className="p-8 text-center">
              <p className="text-gray-500">No more images to vote on</p>
            </div>
          )}
        </div>
      </div>
      <Toaster position="bottom-right" />
    </div>
  );
}

export default App;
